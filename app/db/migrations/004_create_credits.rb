Sequel.migration do
  up do
    create_table(:credits) do
      primary_key :id
      foreign_key :resident_id, :residents, null: false
      Integer :balance, default: 0
      DateTime :updated_at

      index :resident_id
    end

    create_table(:credit_transactions) do
      primary_key :id
      foreign_key :resident_id, :residents, null: false
      Integer :amount, null: false
      Integer :amount_real_currency
      String :payment_gateway_id
      String :status, default: 'pending'
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:credit_usages) do
      primary_key :id
      foreign_key :resident_id, :residents, null: false
      foreign_key :letter_request_id, :letter_requests
      String :service_type, null: false
      Integer :amount, null: false
      DateTime :used_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:credit_transfers) do
      primary_key :id
      foreign_key :from_resident_id, :residents, null: false
      foreign_key :to_resident_id, :residents, null: false
      Integer :amount, null: false
      String :message
      String :status, default: 'pending'
      DateTime :expires_at, default: Sequel.lit("datetime('now', '+3 days')")
      DateTime :confirmed_at
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :from_resident_id
      index :to_resident_id
    end
  end

  down do
    drop_table(:credit_transfers)
    drop_table(:credit_usages)
    drop_table(:credit_transactions)
    drop_table(:credits)
  end
end
