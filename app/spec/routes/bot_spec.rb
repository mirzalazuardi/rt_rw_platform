# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'POST /webhook/telegram' do
  def app
    App.freeze.app
  end

  let(:valid_secret) { 'test-bot-secret' }
  let(:start_update) do
    {
      update_id: 1,
      message: {
        message_id: 1,
        from: { id: 123, first_name: 'Test' },
        chat: { id: 123, type: 'private' },
        text: '/start'
      }
    }.to_json
  end

  before do
    ENV['TELEGRAM_BOT_SECRET'] = valid_secret
  end

  it 'responds 200 with welcome message for /start' do
    header 'X-Telegram-Bot-Api-Secret-Token', valid_secret
    header 'Content-Type', 'application/json'
    post '/webhook/telegram', start_update

    expect(last_response.status).to eq(200)
    expect(last_response.body).not_to be_empty
  end

  it 'returns 403 with wrong secret' do
    header 'X-Telegram-Bot-Api-Secret-Token', 'wrong-secret'
    header 'Content-Type', 'application/json'
    post '/webhook/telegram', start_update

    expect(last_response.status).to eq(403)
  end
end
