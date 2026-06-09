# frozen_string_literal: true

class NumberingConfig < Sequel::Model
  many_to_one :official
  one_to_many :numbering_overrides
end
