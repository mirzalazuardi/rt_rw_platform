# frozen_string_literal: true

class CreditUsage < Sequel::Model
  many_to_one :resident
  many_to_one :letter_request
end
