# frozen_string_literal: true

class LetterRequest < Sequel::Model
  many_to_one :requested_by_resident, class: :Resident
  many_to_one :applicant_resident, class: :Resident
  one_to_many :digital_signatures
  one_to_many :credit_usages
end
