# frozen_string_literal: true

ENV['RACK_ENV'] ||= 'test'

require 'dotenv'
Dotenv.load('.env.test')

ENV['DATABASE_URL'] ||= 'sqlite://test.db'

require 'rack/test'
require 'database_cleaner-sequel'

require_relative '../app/app'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  rescue StandardError
    # DB not connected yet — no-op
  end

  config.around do |example|
    if defined?(DB) && DB.test_connection
      DatabaseCleaner.cleaning { example.run }
    else
      example.run
    end
  end
end
