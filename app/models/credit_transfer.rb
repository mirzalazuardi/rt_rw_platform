# frozen_string_literal: true

class CreditTransfer < Sequel::Model
  many_to_one :from_resident, class: :Resident
  many_to_one :to_resident, class: :Resident
end
