# frozen_string_literal: true

class AdImpression < Sequel::Model
  many_to_one :ad
  many_to_one :resident
end
