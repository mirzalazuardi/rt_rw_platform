# frozen_string_literal: true

class DigitalSignature < Sequel::Model
  many_to_one :letter_request
  many_to_one :official
end
