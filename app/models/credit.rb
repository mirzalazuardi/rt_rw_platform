# frozen_string_literal: true

class Credit < Sequel::Model
  many_to_one :resident
end
