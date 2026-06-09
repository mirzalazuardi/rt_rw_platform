# frozen_string_literal: true

class NumberingOverride < Sequel::Model
  many_to_one :numbering_config
  many_to_one :set_by_official, class: :Official
end
