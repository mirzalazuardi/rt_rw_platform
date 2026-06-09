# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Resident do
  it 'has :residents as table_name' do
    expect(Resident.table_name).to eq(:residents)
  end
end
