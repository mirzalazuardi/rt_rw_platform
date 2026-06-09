Sequel.migration do
  up do
    create_table(:residents) do
      primary_key :id
      String :nik, null: false, unique: true
      String :name, null: false
      String :phone
      Integer :telegram_chat_id
      foreign_key :region_id, :regions, null: false
      String :address
      Integer :family_id
      String :role_in_family, default: 'member'
      TrueClass :registration_pending, default: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :region_id
      index :family_id
    end

    create_table(:families) do
      primary_key :id
      String :no_kk, null: false, unique: true
      foreign_key :head_resident_id, :residents, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at

      index :no_kk
    end

    # Add FK from residents.family_id → families(id) after both exist
    run 'CREATE INDEX idx_residents_family_id ON residents(family_id)'

    create_table(:family_invitations) do
      primary_key :id
      foreign_key :family_id, :families, null: false
      foreign_key :resident_id, :residents, null: false
      foreign_key :invited_by_resident_id, :residents, null: false
      String :token, null: false, unique: true
      String :status, default: 'pending'
      DateTime :expires_at, default: Sequel.lit("datetime('now', '+7 days')")
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at

      index :token
    end

    create_table(:consent_logs) do
      primary_key :id
      foreign_key :resident_id, :residents, null: false
      String :action, null: false
      String :ip
      String :user_agent
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    drop_table(:consent_logs)
    drop_table(:family_invitations)
    drop_table(:families)
    drop_table(:residents)
  end
end
