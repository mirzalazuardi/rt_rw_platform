# frozen_string_literal: true

require 'sequel'
require 'sqlite3'

DB = Sequel.connect(ENV.fetch('DATABASE_URL', 'sqlite://app.db'))

if DB.adapter_scheme == :sqlite
  DB.run('PRAGMA journal_mode=WAL')
  DB.run('PRAGMA busy_timeout=5000')
end
