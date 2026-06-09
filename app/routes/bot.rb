# frozen_string_literal: true

require 'json'

module BotRoutes
  module_function

  def setup(r, roda)
    r.post true do
      secret = ENV.fetch('TELEGRAM_BOT_SECRET', 'dev-secret')
      actual = r.env['HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN']

      unless actual == secret
        roda.response.status = 403
        roda.response.write('Forbidden')
        r.halt
      end

      body = JSON.parse(r.body.read)
      text = body.dig('message', 'text')

      if text == '/start'
        'Selamat datang di Sistem RT/RW! 🏠'
      else
        'OK'
      end
    end
  end
end
