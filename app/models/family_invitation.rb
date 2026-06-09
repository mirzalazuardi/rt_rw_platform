# frozen_string_literal: true

class FamilyInvitation < Sequel::Model
  many_to_one :family
  many_to_one :resident
  many_to_one :invited_by_resident, class: :Resident
end
