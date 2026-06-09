# frozen_string_literal: true

class Region < Sequel::Model
  many_to_one :parent, class: self
  one_to_many :children, class: self, key: :parent_id
  one_to_many :officials
  one_to_many :residents
  one_to_many :ads, key: :target_region_id
  one_to_many :announcements
end
