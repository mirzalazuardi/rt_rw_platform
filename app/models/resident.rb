# frozen_string_literal: true

class Resident < Sequel::Model
  many_to_one :region
  many_to_one :family
  one_to_many :letters_requested,
              class: :LetterRequest, key: :requested_by_resident_id
  one_to_many :letters_as_applicant,
              class: :LetterRequest, key: :applicant_resident_id
  one_to_many :family_invitations, key: :resident_id
  one_to_many :invitations_sent,
              class: :FamilyInvitation, key: :invited_by_resident_id
  one_to_one :credit
  one_to_many :credit_transactions
  one_to_many :credit_usages
  one_to_many :transfers_sent,
              class: :CreditTransfer, key: :from_resident_id
  one_to_many :transfers_received,
              class: :CreditTransfer, key: :to_resident_id
  one_to_many :ad_impressions
  one_to_many :consent_logs
  one_to_many :headed_families, class: :Family, key: :head_resident_id
end
