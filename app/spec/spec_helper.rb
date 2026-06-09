# frozen_string_literal: true

ENV['RACK_ENV'] ||= 'test'

require 'dotenv'
Dotenv.load('.env.test')

ENV['DATABASE_URL'] ||= 'sqlite://test.db'

require 'rack/test'
require 'database_cleaner-sequel'

DatabaseCleaner.allow_remote_database_url = true if ENV['DATABASE_URL'].start_with?('sqlite')

require_relative '../app/app'

Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path('../db/migrations', __dir__))

require_relative '../config/models'

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
