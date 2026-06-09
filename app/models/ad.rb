# frozen_string_literal: true

class Ad < Sequel::Model
  many_to_one :target_region, class: :Region
  many_to_one :approved_by_official, class: :Official
  one_to_many :ad_impressions
end
