# frozen_string_literal: true

class Announcement < Sequel::Model
  many_to_one :region
  many_to_one :official
end
