Sequel.migration do
  up do
    create_table(:ads) do
      primary_key :id
      String :business_name, null: false
      String :content, null: false
      foreign_key :target_region_id, :regions
      Date :start_date
      Date :end_date
      String :status, default: 'pending'
      foreign_key :approved_by_official_id, :officials
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:ad_impressions) do
      primary_key :id
      foreign_key :ad_id, :ads, null: false
      foreign_key :resident_id, :residents, null: false
      DateTime :seen_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:announcements) do
      primary_key :id
      foreign_key :region_id, :regions, null: false
      foreign_key :official_id, :officials, null: false
      String :title, null: false
      String :content
      String :image_url
      DateTime :sent_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:numbering_configs) do
      primary_key :id
      foreign_key :official_id, :officials, null: false
      String :letter_type, null: false
      String :prefix
      String :format_template, null: false
      Integer :last_sequence_number, default: 0
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at

      unique %i[official_id letter_type]
    end

    create_table(:numbering_overrides) do
      primary_key :id
      foreign_key :numbering_config_id, :numbering_configs, null: false
      Integer :new_sequence_number, null: false
      String :reason
      foreign_key :set_by_official_id, :officials, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    drop_table(:numbering_overrides)
    drop_table(:numbering_configs)
    drop_table(:announcements)
    drop_table(:ad_impressions)
    drop_table(:ads)
  end
end
