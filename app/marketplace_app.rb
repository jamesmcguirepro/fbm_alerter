# frozen_string_literal: true

require 'sinatra/base'

require 'rack/method_override'

require_relative 'helpers'
require_relative 'routes/dashboard'
require_relative 'routes/searches'
require_relative 'routes/listings'
require_relative 'routes/alerts'
require_relative 'routes/settings'

class MarketplaceApp < Sinatra::Base
  enable :sessions
  use Rack::MethodOverride
  # LAN-only, single-user tool: no CSRF token burden for htmx forms.
  set :protection, except: :authenticity_token
  set :session_secret, ENV.fetch('SESSION_SECRET', '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef')
  set :views, File.expand_path(File.join(__dir__, 'views'))
  set :public_folder, File.expand_path(File.join(__dir__, '..', 'public'))

  set :bind, '0.0.0.0'
  set :port, ENV.fetch('PORT', 9292).to_i
  set :show_exceptions, false

  helpers ViewHelpers

  get '/health' do
    content_type :json
    { status: 'ok', version: VERSION }.to_json
  end

  get '/' do
    redirect '/dashboard'
  end

  error do
    content_type :json
    { status: 'error', message: env['sinatra.error'].message }.to_json
  end
end
