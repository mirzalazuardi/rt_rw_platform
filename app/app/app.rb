# frozen_string_literal: true

require 'roda'
require 'rodauth'
require 'dotenv/load' if File.exist?(File.expand_path('../../.env', __dir__))
require_relative '../config/database'

class App < Roda
  plugin :json
  plugin :rodauth, csrf: false do
    enable :login, :logout, :create_account, :reset_password
    db DB
    account_password_hash_column :password_hash
    email_from 'noreply@rt-rw.local'
  end

  plugin :flash
  plugin :sessions, secret: ENV.fetch('SESSION_SECRET', 'dev-secret-change-me')

  route do |r|
    r.rodauth

    r.on 'health' do
      r.get do
        'OK'
      end
    end

    r.on 'dashboard' do
      rodauth.require_authentication
      r.get do
        'Dashboard OK'
      end
    end
  end
end
