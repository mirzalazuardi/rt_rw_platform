# PRD Final – Sistem Informasi Manajemen RT/RW (Telegram Mini App)

**Versi:** 3.1  
**Tanggal:** 2026-06-10  
**Status:** Final – Siap Implementasi  

---

## 1. Ringkasan Eksekutif

**Produk:** Platform digital untuk RT/RW, kelurahan, dan kecamatan yang memungkinkan warga mengurus surat pengantar, membeli kredit premium, transfer kredit, dan menerima pengumuman via Telegram Mini App.

**Model Bisnis:**
- **Gratis selamanya** untuk semua official (RT, RW, Lurah, Camat).
- **Sumber profit:**
  1. Penjualan kredit premium kepada warga (materai digital, pengiriman fisik surat, cetak dokumen).
  2. Iklan berbayar dari bisnis lokal.
  3. Laporan data agregat anonim (fase 2).

**Prinsip Pengembangan:**
- Kode mengutamakan **clarity** dan SOLID (Sandi Metz).
- Setiap fitur wajib disertai **RSpec** (Ruby) dan **unit test** (Go).
- **State machine** surat menggunakan `aasm` gem di Ruby.
- **Background job & PDF generation** menggunakan **Go + Asynq** + Redis.
- **Database** SQLite (WAL) untuk MVP, siap migrasi ke PostgreSQL.
- **Semua transaksi keuangan mematuhi ACID**.
- **Family Account:** Satu akun Telegram mewakili satu KK. Kepala keluarga mendaftarkan KK, mengundang anggota, anggota harus memberikan persetujuan (consent).
- **Autentikasi official** menggunakan **Rodauth** (login, session, reset password).
- **ORM** menggunakan **Sequel** (migrasi, model, validasi).

---

## 2. Target Pengguna & Persona

| Pengguna | Peran | Akses | Autentikasi | Monetisasi |
|----------|-------|-------|--------------|-------------|
| Warga (Kepala Keluarga) | Daftarkan KK, undang anggota, ajukan surat untuk diri sendiri atau anggota lain | Mini App | Telegram initData + verifikasi KK | Membeli kredit |
| Warga (Anggota Keluarga) | Ajukan surat untuk diri sendiri (setelah menerima undangan dan setuju) | Mini App | Telegram initData + persetujuan undangan | Membeli kredit |
| Ketua RT | Mengesahkan surat, kelola warga, kirim pengumuman, approve iklan | Dashboard Web + Bot | Rodauth (email + password) | Gratis |
| Sekretaris RW | Mengelola multi-RT, laporan | Dashboard Web | Rodauth | Gratis |
| Lurah/Kades | Mengesahkan surat (fase 2) | Dashboard Web | Rodauth | Gratis |
| Camat | Mengesahkan surat (fase 2) | Dashboard Web | Rodauth | Gratis |
| Bisnis Lokal | Pasang iklan, lihat laporan | Web terpisah | Email + password | Berbayar |

**Asumsi awal:** 1 RW dengan 5 RT (150 KK). Setiap KK rata-rata 4 anggota. Hanya kepala keluarga dan anggota dewasa yang diundang akan memiliki akun Telegram terikat.

---

## 3. Fitur MVP (Prioritas)

### 3.1 Manajemen Keluarga (Family Account)

#### 3.1.1 Registrasi Kartu Keluarga (Kepala Keluarga)
- Kepala keluarga membuka Mini App, memilih "Daftarkan Keluarga".
- Memasukkan **Nomor KK** dan **NIK Kepala Keluarga**.
- Sistem memverifikasi data (validasi format, cegah duplikasi KK, opsional integrasi dengan data awal dari CSV atau API Dukcapil).
- Jika valid, sistem membuat:
  - Satu record `families` (no_kk, head_resident_id).
  - Satu record `residents` untuk kepala keluarga dengan `role_in_family = 'head'`, `telegram_chat_id` diisi dari akun yang login.
- Kepala keluarga langsung terikat dan dapat menggunakan aplikasi.

#### 3.1.2 Pengelolaan Anggota & Undangan
- Setelah KK terdaftar, sistem secara otomatis membuat placeholder `residents` untuk setiap anggota keluarga (data bisa diimpor dari CSV unggahan kepala keluarga, atau dari file awal). Setiap placeholder memiliki status `registration_pending = true` dan `telegram_chat_id = NULL`.
- Kepala keluarga melihat daftar anggota yang belum terikat. Untuk setiap anggota, dapat mengirim **undangan via Telegram** (jika nomor/username tersedia) atau membagikan tautan undangan.
- Sistem membuat record di `family_invitations` dengan token unik, masa berlaku 7 hari.

#### 3.1.3 Persetujuan (Consent) Anggota Keluarga
- Anggota menerima tautan undangan (misal `https://t.me/YourBot?start=invite_<token>`).
- Membuka Mini App, sistem menampilkan informasi keluarga dan data anggota (nama, NIK, alamat – disembunyikan sebagian untuk privasi).
- Anggota menekan tombol **Setuju** atau **Tolak**.
- Jika **Setuju**:
  - Dalam satu transaksi ACID: update `residents` yang bersangkutan dengan `telegram_chat_id` (dari akun yang login), `family_id`, `role_in_family = 'member'`, `registration_pending = false`.
  - Update `family_invitations.status = 'accepted'`.
  - Catat log persetujuan di `consent_logs` (waktu, IP, user agent).
  - Anggota kini dapat mengajukan surat untuk dirinya sendiri.
- Jika **Tolak**:
  - Update `family_invitations.status = 'rejected'`.
  - Tidak ada perubahan data.

#### 3.1.4 Hak dan Batasan
- **Kepala keluarga** dapat mengajukan surat untuk **dirinya sendiri** dan untuk **anggota keluarga lain** (atas nama mereka).
- **Anggota keluarga** hanya dapat mengajukan surat untuk **dirinya sendiri**.
- Untuk mengajukan surat atas nama anggota lain, kepala keluarga harus memilih nama pemohon dari daftar keluarga.
- Semua surat yang diajukan akan mencantumkan NIK pemohon yang sebenarnya dan nomor KK sebagai identitas keluarga.
- Fitur **delegasi penuh** (anggota mewakili anggota lain) tidak termasuk dalam MVP, tetapi dapat ditambahkan di fase 2 sebagai "surat kuasa digital".

### 3.2 Permintaan Surat Pengantar (State Machine dengan `aasm`)
**Jenis surat:** `ktp`, `kk`, `domisili`.

**State flow:**
```
draft → pending_rt → pending_rw → pending_lurah → pending_camat → completed
↓ (reject) → rejected
```

- Warga (kepala keluarga atau anggota) mengisi form: pilih **pemohon** (jika kepala keluarga, bisa pilih diri sendiri atau anggota lain; jika anggota, hanya dirinya sendiri).
- Submit → status `pending_rt`, notifikasi RT.
- RT setujui → sistem memanggil Go worker untuk generate PDF, tanda tangan digital VIDA Sign, simpan PDF, update status.
- Surat yang sudah ditandatangani dikirim ke pemohon (akun Telegram pemohon yang bersangkutan).

### 3.3 Tanda Tangan Digital & Materai (VIDA Sign)
- **Official:** 10 tanda tangan digital gratis pertama.
- **Warga** membeli kredit untuk materai digital, tanda tangan tambahan, pengiriman fisik, cetak dokumen.

### 3.4 Penomoran Dokumen Custom
- Setiap official dapat mengatur format nomor surat per jenis surat.
- Placeholder: `{prefix}`, `{seq}`, `{seq:04d}`, `{year}`, `{month}`, `{type}`.
- Override nomor awal dicatat di tabel `numbering_overrides`.

### 3.5 Kredit Warga & Transfer Kredit
- Warga membeli paket kredit (Starter, Keluarga, Pro) via Midtrans/Xendit.
- Kredit digunakan untuk materai digital, tanda tangan tambahan, pengiriman surat fisik, cetak dokumen.
- Transfer kredit antar warga dengan konfirmasi penerima, batas harian, dan masa kadaluwarsa 3 hari.
- **Kredit melekat pada individu warga** (bukan per KK). Setiap anggota keluarga memiliki saldo sendiri.

### 3.6 Iklan & Pengumuman
- Bisnis lokal pasang iklan (CPM/CPC sederhana) dengan persetujuan RT.
- RT/RW kirim pengumuman ke warga via bot.

---

## 4. Arsitektur Teknis

### 4.1 Komponen dan Bahasa

| Komponen | Teknologi | Alasan |
|----------|-----------|--------|
| **Backend utama** | Ruby + Roda | Familiar, ringan, clarity tinggi. |
| **Autentikasi Official** | **Rodauth** | Fitur lengkap (login, session, password hash, CSRF), mudah diintegrasikan dengan Roda. |
| **Database ORM** | **Sequel** | Fleksibel, performa baik, mendukung SQLite dan PostgreSQL, migrasi terstruktur. |
| **Background job & PDF** | Go + Asynq | Efisien memori (~30-50MB), mudah dipelajari. |
| **Message broker** | Redis | Didukung Asynq, ringan (~200MB). |
| **Database** | SQLite (WAL) → PostgreSQL | SQLite hemat, migrasi mudah. |
| **State machine** | `aasm` gem | Logika status surat terpusat. |
| **Tanda tangan digital** | VIDA Sign API | Legal, gratis 10 pertama. |
| **Frontend Mini App** | HTML + Vanilla JS | Ringan, kompatibel WebView. |
| **Bot Telegram** | Telegem (Ruby) | Ringan, integrasi Roda. |
| **PDF generation** | Go + wkhtmltopdf | HTML ke PDF, template mudah. |
| **Payment gateway** | Midtrans / Xendit | Populer di Indonesia. |
| **Deployment** | VPS 2GB (2 core) | Biaya minimal ($4.2/bulan). |

### 4.2 Autentikasi dengan Rodauth

- **Untuk Official (RT, RW, Lurah, Camat):**  
  Menggunakan Rodauth dengan fitur:
  - Login via email/username dan password.
  - Session berbasis cookie (dengan CSRF protection).
  - Password hashing (bcrypt/Argon2).
  - Fitur lupa password (reset via email).
  - Opsional: 2FA (fase 2).
  - Setiap official akan memiliki akun di tabel `accounts` (kelola oleh Rodauth). Kemudian dihubungkan ke tabel `officials` (data spesifik seperti region_id, role, credential VIDA).

- **Untuk Warga (Mini App):**  
  Autentikasi **tetap menggunakan Telegram `initData`** (tanpa Rodauth). Warga tidak perlu login dengan password. Setiap request ke API backend (selain endpoint publik) harus menyertakan `initData` yang divalidasi di sisi server.

- **Dashboard Official:**  
  Dibangun dengan Roda + Rodauth. Setelah login, official dapat mengakses halaman dashboard (HTML) dan API endpoints yang dilindungi session.

- **API untuk Mini App:**  
  Dilindungi oleh validasi `initData` (bukan session). Bisa menggunakan middleware Roda khusus.

### 4.3 Database ORM: Sequel

- **Migrasi:** Menggunakan `sequel-migrate`. Semua perubahan skema database dikelola melalui migrasi.
- **Model:** Setiap tabel memiliki model Sequel. Relasi, validasi, dan hook dapat didefinisikan di model.
- **Koneksi:** Konfigurasi `Sequel::Database` disimpan di `config/database.rb`.
- **Transaksi ACID:** Sequel mendukung `DB.transaction` dengan isolasi level. Untuk SQLite, gunakan `DB.transaction(immediate: true)` untuk lock database.

**Contoh model:**

```ruby
# models/resident.rb
class Resident < Sequel::Model
  many_to_one :family
  one_to_many :letter_requests, key: :applicant_resident_id
end

# models/letter_request.rb
class LetterRequest < Sequel::Model
  include AASM
  many_to_one :applicant_resident, class: 'Resident'
  aasm column: :status do
    state :draft, initial: true
    state :pending_rt
    # ...
  end
end
```

### 4.4 Integrasi Rodauth dengan Sequel
Rodauth akan secara otomatis menggunakan koneksi Sequel yang sama. Contoh konfigurasi:

```ruby
# roda_app.rb
require 'roda'
require 'sequel'
require 'rodauth'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://app.db')

class App < Roda
  plugin :rodauth do
    enable :login, :logout, :create_account, :reset_password
    account_password_hash_column :password_hash
  end

  route do |r|
    r.rodauth          # handle /login, /logout, dll

    r.on 'dashboard' do
      rodauth.require_authentication
      # ...
    end

    r.on 'api' do
      # middleware validasi initData
    end
  end
end
```

### 4.5 Diagram Arsitektur

```
┌─────────────────────────────────────────────────────────────┐
│                        VPS 2GB                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Ruby       │    │   Redis      │    │   Go Worker  │  │
│  │   (Roda)     │◄──►│  (broker)    │◄──►│  (Asynq)     │  │
│  │   :9292      │    │   :6379      │    │   :8080      │  │
│  └──────┬───────┘    └──────────────┘    └──────┬───────┘  │
│         │                                        │          │
│         ▼                                        ▼          │
│  ┌──────────────┐                        ┌──────────────┐  │
│  │   SQLite     │                        │  wkhtmltopdf │  │
│  │  (database)  │                        │  (binary)    │  │
│  └──────────────┘                        └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
        │                                                   │
        ▼                                                   ▼
   Telegram API                                        VIDA Sign API
   (bot, Mini App)                                     (tanda tangan)
```

### 4.6 Komunikasi Ruby ↔ Go
1. Ruby (Roda) menerima request approve dari RT.
2. Ruby menghasilkan nomor dokumen, membuat HTML template surat, menyimpannya sementara.
3. Ruby mengirim job ke Go worker via HTTP POST /enqueue (payload JSON).
4. Go worker menerima, enqueue ke Asynq (Redis).
5. Asynq worker memproses:
   - Generate PDF dari HTML (wkhtmltopdf).
   - Kirim ke VIDA Sign API (inline sign).
   - Simpan PDF yang sudah ditandatangani.
6. Panggil callback HTTP ke Ruby (/webhooks/vida_callback).
7. Ruby menerima callback, update status surat, kirim PDF ke warga via bot.

**Endpoint Go worker:**
- `POST /enqueue` → menerima job.
- `GET /health` → health check.

**Webhook Ruby:**
- `POST /webhooks/vida_callback` → menerima notifikasi dari Go.

---

## 5. Skema Database (SQLite Final)

Semua tabel dikelola melalui migrasi Sequel. Berikut DDL lengkap (untuk referensi):

```sql
-- 1. Wilayah
CREATE TABLE regions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  level TEXT NOT NULL,
  parent_id INTEGER,
  code TEXT UNIQUE NOT NULL,
  name TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parent_id) REFERENCES regions(id)
);

-- 2. Pengurus (official) – terhubung ke akun Rodauth
CREATE TABLE officials (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL,   -- dari tabel accounts (rodauth)
  region_id INTEGER NOT NULL,
  role TEXT NOT NULL,
  name TEXT NOT NULL,
  telegram_user_id INTEGER,
  vida_api_key_encrypted TEXT,
  vida_private_key_encrypted TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (region_id) REFERENCES regions(id),
  FOREIGN KEY (account_id) REFERENCES accounts(id),
  UNIQUE(region_id, role)
);

-- 3. Keluarga (KK)
CREATE TABLE families (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  no_kk TEXT UNIQUE NOT NULL,
  head_resident_id INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (head_resident_id) REFERENCES residents(id)
);

-- 4. Warga
CREATE TABLE residents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nik TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  telegram_chat_id INTEGER,
  region_id INTEGER NOT NULL,
  address TEXT,
  family_id INTEGER,
  role_in_family TEXT DEFAULT 'member',
  registration_pending BOOLEAN DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (region_id) REFERENCES regions(id),
  FOREIGN KEY (family_id) REFERENCES families(id)
);

-- 5. Undangan keluarga
CREATE TABLE family_invitations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  family_id INTEGER NOT NULL,
  resident_id INTEGER NOT NULL,
  invited_by_resident_id INTEGER NOT NULL,
  token TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'pending',
  expires_at DATETIME DEFAULT (DATETIME('now', '+7 days')),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (family_id) REFERENCES families(id),
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  FOREIGN KEY (invited_by_resident_id) REFERENCES residents(id)
);

-- 6. Log persetujuan
CREATE TABLE consent_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  ip TEXT,
  user_agent TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (resident_id) REFERENCES residents(id)
);

-- 7. Permintaan surat
CREATE TABLE letter_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  requested_by_resident_id INTEGER NOT NULL,
  applicant_resident_id INTEGER NOT NULL,
  letter_type TEXT NOT NULL,
  reason TEXT,
  status TEXT DEFAULT 'draft',
  pdf_path TEXT,
  document_number TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (requested_by_resident_id) REFERENCES residents(id),
  FOREIGN KEY (applicant_resident_id) REFERENCES residents(id)
);

-- 8. Tanda tangan digital
CREATE TABLE digital_signatures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  letter_request_id INTEGER NOT NULL,
  official_id INTEGER NOT NULL,
  vida_sign_request_id TEXT,
  signed_at DATETIME,
  FOREIGN KEY (letter_request_id) REFERENCES letter_requests(id),
  FOREIGN KEY (official_id) REFERENCES officials(id)
);

-- 9. Kredit
CREATE TABLE credits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER NOT NULL,
  balance INTEGER DEFAULT 0,
  updated_at DATETIME,
  FOREIGN KEY (resident_id) REFERENCES residents(id)
);

-- 10. Transaksi top-up
CREATE TABLE credit_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  amount_real_currency INTEGER,
  payment_gateway_id TEXT,
  status TEXT DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (resident_id) REFERENCES residents(id)
);

-- 11. Penggunaan kredit
CREATE TABLE credit_usages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER NOT NULL,
  letter_request_id INTEGER,
  service_type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  used_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (resident_id) REFERENCES residents(id),
  FOREIGN KEY (letter_request_id) REFERENCES letter_requests(id)
);

-- 12. Transfer kredit
CREATE TABLE credit_transfers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_resident_id INTEGER NOT NULL,
  to_resident_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  message TEXT,
  status TEXT DEFAULT 'pending',
  expires_at DATETIME DEFAULT (DATETIME('now', '+3 days')),
  confirmed_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (from_resident_id) REFERENCES residents(id),
  FOREIGN KEY (to_resident_id) REFERENCES residents(id)
);

-- 13. Iklan
CREATE TABLE ads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_name TEXT NOT NULL,
  content TEXT NOT NULL,
  target_region_id INTEGER,
  start_date DATE,
  end_date DATE,
  status TEXT DEFAULT 'pending',
  approved_by_official_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (target_region_id) REFERENCES regions(id),
  FOREIGN KEY (approved_by_official_id) REFERENCES officials(id)
);

-- 14. Tayangan iklan
CREATE TABLE ad_impressions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ad_id INTEGER NOT NULL,
  resident_id INTEGER NOT NULL,
  seen_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ad_id) REFERENCES ads(id),
  FOREIGN KEY (resident_id) REFERENCES residents(id)
);

-- 15. Pengumuman
CREATE TABLE announcements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  region_id INTEGER NOT NULL,
  official_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  image_url TEXT,
  sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (region_id) REFERENCES regions(id),
  FOREIGN KEY (official_id) REFERENCES officials(id)
);

-- 16. Konfigurasi penomoran
CREATE TABLE numbering_configs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  official_id INTEGER NOT NULL,
  letter_type TEXT NOT NULL,
  prefix TEXT,
  format_template TEXT NOT NULL,
  last_sequence_number INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (official_id) REFERENCES officials(id),
  UNIQUE(official_id, letter_type)
);

-- 17. Override nomor
CREATE TABLE numbering_overrides (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numbering_config_id INTEGER NOT NULL,
  new_sequence_number INTEGER NOT NULL,
  reason TEXT,
  set_by_official_id INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (numbering_config_id) REFERENCES numbering_configs(id),
  FOREIGN KEY (set_by_official_id) REFERENCES officials(id)
);

-- Index
CREATE INDEX idx_residents_region ON residents(region_id);
CREATE INDEX idx_residents_family ON residents(family_id);
CREATE INDEX idx_families_no_kk ON families(no_kk);
CREATE INDEX idx_letter_requests_applicant ON letter_requests(applicant_resident_id);
CREATE INDEX idx_letter_requests_status ON letter_requests(status);
CREATE INDEX idx_credits_resident ON credits(resident_id);
CREATE INDEX idx_credit_transfers_from ON credit_transfers(from_resident_id);
CREATE INDEX idx_credit_transfers_to ON credit_transfers(to_resident_id);
CREATE INDEX idx_family_invitations_token ON family_invitations(token);
```

**Catatan:** Tabel `accounts` dan tabel terkait Rodauth akan dibuat secara otomatis oleh rodauth.

---

## 6. Prinsip ACID pada Transaksi Keuangan

Semua transaksi yang mengubah saldo kredit, nomor urut, atau status persetujuan keluarga harus mematuhi ACID.

- Gunakan transaksi eksplisit `DB.transaction(immediate: true)` di SQLite.
- Untuk transfer kredit, kurangi saldo hanya saat konfirmasi dalam satu transaksi atomic.
- Untuk generate nomor dokumen, lakukan `SELECT ... FOR UPDATE` (atau cukup dengan transaksi immediate).

Contoh di Ruby (Sequel):

```ruby
DB.transaction(immediate: true) do
  credit = Credit.where(resident_id: id).first
  credit.update(balance: credit.balance - amount)
end
```

Contoh di Go (dengan SQLite):

```go
tx, err := db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
// ... query
tx.Commit()
```

---

## 7. Integrasi VIDA Sign

**API Inline Sign:**
- Endpoint: `POST https://api.vida.id/v1/sign/inline`
- Header: `Authorization: Bearer <access_token>`
- Body: `document` (base64 PDF), `signers`, `signature_placement`
- Response: `signed_document` (base64 PDF)

Penanganan error: Retry 3x oleh Asynq, setelah gagal status surat `failed`.

---

## 8. Monitoring & Scaling

| Indikator | Ambang Batas | Tindakan |
|-----------|-------------|----------|
| Memory usage | > 75% | Upgrade VPS 2GB → 4GB |
| Swap usage | > 500MB | Upgrade atau migrasi PostgreSQL |
| SQLite lock | > 5 detik | Migrasi ke PostgreSQL |
| RW aktif | > 10 RW | Upgrade VPS + migrasi PostgreSQL |

**Monitoring tools:** htop, redis-cli INFO memory, asynqmon, journalctl.

---

## 9. Rencana Iterasi Pasca-MVP (Fase 2)

1. Tanda tangan digital RW/Lurah/Camat (alur berjenjang penuh).
2. Integrasi Dukcapil untuk auto-fill anggota KK.
3. Delegasi surat kuasa digital (anggota mewakili anggota lain).
4. Pembayaran iuran digital otomatis.
5. Dashboard kelurahan/kecamatan.
6. Laporan data agregat anonim.

---

## 10. Milestone (6 minggu)

| Minggu | Aktivitas | Output |
|--------|-----------|--------|
| 1 | Setup VPS (Ubuntu, Redis, Go, wkhtmltopdf). Setup project Ruby: Roda, Sequel, Rodauth, migrasi database. | Bot /start berjalan, database siap, Rodauth berfungsi. |
| 2 | Implementasi model Sequel untuk semua tabel. Autentikasi official via Rodauth (dashboard login). | Official bisa login ke dashboard. |
| 3 | Manajemen warga (import CSV), registrasi KK, undangan anggota, persetujuan (menggunakan Sequel models). | Kepala keluarga bisa daftar dan undang anggota. |
| 4 | Fitur permintaan surat (pilih pemohon), state machine aasm, integrasi dengan Sequel. | Surat bisa diajukan. |
| 5 | Integrasi Go worker (PDF, VIDA Sign callback), penomoran custom (menggunakan Sequel transaksi). | Tanda tangan digital RT berhasil. |
| 6 | Kredit, transfer kredit, top-up dummy, uji coba dengan 1 RT. | MVP siap launch. |

---

## 11. Risiko & Mitigasi

| Risiko | Mitigasi |
|--------|----------|
| Anggota keluarga tidak punya Telegram | Kepala keluarga bisa bagikan tautan undangan via WhatsApp/SMS. |
| Penyalahgunaan identitas | Verifikasi token unik dan persetujuan via akun Telegram sendiri. |
| Kepala keluarga daftarkan KK orang lain | Di MVP, terima risiko kecil. Fase 2 integrasi Dukcapil. |
| VIDA Sign free tier habis | Official beli kredit; warga beli sendiri. |
| SQLite lock berlebihan | WAL mode + busy_timeout; siap migrasi ke PostgreSQL. |
| Lupa password official | Rodauth menyediakan reset password via email. |

---

## 12. Kesimpulan

PRD Final Versi 3.1 ini mendefinisikan fondasi untuk membangun SaaS RT/RW dengan biaya operasional minimal (VPS $4.2/bulan) dan model bisnis berkelanjutan. Fitur Family Account, ACID, dan arsitektur Ruby+Go tetap dipertahankan. Penggunaan Rodauth dan Sequel akan mempercepat pengembangan, meningkatkan keamanan, serta memudahkan perawatan kode.

**Langkah selanjutnya:** Implementasi skeleton kode sesuai PRD.

---

Dokumen ini siap dijadikan acuan pengembangan.
