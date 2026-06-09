Sequel.migration do
  up do
    create_table(:regions) do
      primary_key :id
      String :level, null: false
      foreign_key :parent_id, :regions, on_delete: :set_null
      String :code, null: false, unique: true
      String :name
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :code
    end

    create_table(:accounts) do
      primary_key :id
      String :email, null: false, unique: true
      String :password_hash
      Integer :status_id, default: 1
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:officials) do
      primary_key :id
      foreign_key :account_id, :accounts, null: false
      foreign_key :region_id, :regions, null: false
      String :role, null: false
      String :name, null: false
      Integer :telegram_user_id
      String :vida_api_key_encrypted
      String :vida_private_key_encrypted
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      unique %i[region_id role]
    end
  end

  down do
    drop_table(:officials)
    drop_table(:accounts)
    drop_table(:regions)
  end
end
