# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe App do
  def app
    App.freeze.app
  end

  describe 'GET /health' do
    it 'returns 200 OK' do
      get '/health'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
    end
  end
end
