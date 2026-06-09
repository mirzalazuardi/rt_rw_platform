# frozen_string_literal: true

class Family < Sequel::Model
  many_to_one :head_resident, class: :Resident
  one_to_many :residents
  one_to_many :family_invitations
end
