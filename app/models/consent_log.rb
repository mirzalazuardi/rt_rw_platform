# frozen_string_literal: true

class ConsentLog < Sequel::Model
  many_to_one :resident
end
