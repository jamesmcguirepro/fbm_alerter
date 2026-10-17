# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers ViewHelpers

  get '/settings' do
    erb :settings
  end

  post '/settings/test-email' do
    to = params[:email].to_s.strip

    if to.empty?
      session[:flash_error] = 'Please provide a recipient email address.'
    else
      begin
        Mailer.send_email(
          to:,
          from: Config.email_from,
          subject: 'Marketplace Monitor — Test Email',
          html_body: '<p>This is a test email from your Marketplace Monitor.</p>'
        )
        session[:flash] = "Test email sent to #{to}."
      rescue StandardError => e
        session[:flash_error] = "Failed to send test email: #{e.message}"
      end
    end

    redirect '/settings'
  end
end
