# frozen_string_literal: true

class Official < Sequel::Model
  many_to_one :account
  many_to_one :region
  one_to_many :digital_signatures
  one_to_many :ads, key: :approved_by_official_id
  one_to_many :announcements
  one_to_many :numbering_configs
  one_to_many :numbering_overrides, key: :set_by_official_id
end
