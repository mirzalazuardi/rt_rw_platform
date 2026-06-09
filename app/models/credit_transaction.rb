# frozen_string_literal: true

class CreditTransaction < Sequel::Model
  many_to_one :resident
end
