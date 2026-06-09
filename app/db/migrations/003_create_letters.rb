Sequel.migration do
  up do
    create_table(:letter_requests) do
      primary_key :id
      foreign_key :requested_by_resident_id, :residents, null: false
      foreign_key :applicant_resident_id, :residents, null: false
      String :letter_type, null: false
      String :reason
      String :status, default: 'draft'
      String :pdf_path
      String :document_number
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at

      index :applicant_resident_id
      index :status
    end

    create_table(:digital_signatures) do
      primary_key :id
      foreign_key :letter_request_id, :letter_requests, null: false
      foreign_key :official_id, :officials, null: false
      String :vida_sign_request_id
      DateTime :signed_at
    end
  end

  down do
    drop_table(:digital_signatures)
    drop_table(:letter_requests)
  end
end
