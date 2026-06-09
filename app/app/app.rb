# frozen_string_literal: true

require 'roda'
require 'dotenv/load' if File.exist?(File.expand_path('../../.env', __dir__))
require_relative '../config/database'

class App < Roda
  plugin :json

  route do |r|
    r.on 'health' do
      r.get do
        'OK'
      end
    end
  end
end
