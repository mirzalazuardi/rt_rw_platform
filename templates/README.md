# Folder Template Surat

Folder ini berisi template surat resmi dalam format Markdown yang digunakan
oleh sistem RT/RW Platform untuk menghasilkan dokumen PDF melalui Go worker
(wkhtmltopdf + VIDA Sign).

## Jenis Template

| File | Kode (`letter_type`) | Keterangan |
|------|----------------------|-----------|
| `surat_pengantar_ktp.md` | `ktp` | Surat pengantar permohonan pembuatan/perpanjangan KTP |
| `surat_pengantar_kk.md` | `kk` | Surat pengantar permohonan pembuatan/perubahan KK |
| `surat_keterangan_domisili.md` | `domisili` | Surat keterangan tempat tinggal/domisili |
| `surat_keterangan_tidak_mampu.md` | `sktm` | Surat keterangan tidak mampu secara ekonomi |
| `surat_pindah.md` | `pindah` | Surat keterangan pindah tempat tinggal |

## Cara Kerja

1. Ketua RT menyetujui permohonan surat di dashboard.
2. Ruby (Roda) memilih template sesuai `letter_type`, mengisi placeholder
   dengan data dari database, lalu menyimpan HTML sementara.
3. Ruby mengirim job ke Go worker via `POST /enqueue`.
4. Go worker mengonversi HTML → PDF (wkhtmltopdf), mengirim ke VIDA Sign,
   lalu mengirim PDF yang telah ditandatangani ke Telegram warga.

## Placeholder

Semua placeholder menggunakan format `{{nama_placeholder}}`.
Placeholder diisi oleh Ruby sebelum dikirim ke Go worker.

### Placeholder Umum (tersedia di semua template)

| Placeholder | Sumber | Keterangan |
|---|---|---|
| `{{nomor_surat}}` | `letter_requests.document_number` | Nomor surat otomatis dari `numbering_configs` |
| `{{tanggal_surat}}` | `letter_requests.created_at` | Tanggal surat dibuat (format: DD MMMM YYYY) |
| `{{nama_pemohon}}` | `residents.name` | Nama lengkap pemohon |
| `{{nik_pemohon}}` | `residents.nik` | NIK pemohon (16 digit) |
| `{{no_kk}}` | `families.no_kk` | Nomor Kartu Keluarga |
| `{{tempat_lahir}}` | `residents.tempat_lahir` | Tempat lahir |
| `{{tanggal_lahir}}` | `residents.tanggal_lahir` | Tanggal lahir (format: DD MMMM YYYY) |
| `{{jenis_kelamin}}` | `residents.jenis_kelamin` | Laki-laki / Perempuan |
| `{{agama}}` | `residents.agama` | Agama pemohon |
| `{{pekerjaan}}` | `residents.pekerjaan` | Pekerjaan pemohon |
| `{{alamat}}` | `residents.address` | Alamat lengkap |
| `{{rt_nomor}}` | `regions.code` (level RT) | Nomor RT |
| `{{rw_nomor}}` | `regions.code` (level RW) | Nomor RW |
| `{{kelurahan}}` | `regions.name` (level kelurahan) | Nama kelurahan |
| `{{kecamatan}}` | `regions.name` (level kecamatan) | Nama kecamatan |
| `{{kota}}` | `regions.name` (level kota) | Nama kota/kabupaten |
| `{{provinsi}}` | `regions.name` (level provinsi) | Nama provinsi |
| `{{keperluan}}` | `letter_requests.reason` | Keperluan/alasan permohonan |
| `{{nama_ketua_rt}}` | `officials.name` (role RT) | Nama Ketua RT |
| `{{nama_ketua_rw}}` | `officials.name` (role RW) | Nama Ketua RW |
| `{{tanda_tangan_digital}}` | VIDA Sign callback | Blok tanda tangan digital (disisipkan oleh Go worker) |

### Placeholder Khusus

Placeholder berikut hanya tersedia pada template tertentu:

| Placeholder | Template | Sumber | Keterangan |
|---|---|---|---|
| `{{alamat_tujuan}}` | `surat_pindah` | `letter_requests` (field tambahan) | Alamat tujuan pindah |
| `{{alasan_pindah}}` | `surat_pindah` | `letter_requests.reason` | Alasan kepindahan |

## Konvensi Penulisan Template

- Gunakan Bahasa Indonesia baku.
- Kop surat ditulis di bagian atas dengan pemisah garis `---`.
- Nomor surat selalu pada baris pertama isi surat.
- Blok tanda tangan di bagian kanan bawah.
- Jangan ubah nama placeholder — perubahan harus sinkron dengan kode Ruby
  di `app/services/letter_renderer.rb`.
