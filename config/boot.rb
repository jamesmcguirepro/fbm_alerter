# frozen_string_literal: true

# Single boot path shared by the CLI (main.rb) and the web app (config.ru).
# Require this file once before anything else.

require 'active_record'
require 'active_support/all'
require 'discard'
require 'dotenv/load'
require 'httparty'
require 'json'
require 'mail'
require 'puma'
require 'rack'
require 'rake'
require 'sinatra'
require 'sqlite3'
require 'thor'
require 'zeitwerk'

# --- Zeitwerk autoloading -----------------------------------------------------

loader = Zeitwerk::Loader.new
loader.tag = 'marketplace_monitor'
loader.inflector.inflect('cli' => 'CLI', 'monitor' => 'MarketplaceMonitor')
loader.push_dir(File.join(__dir__, '..', 'lib'))
loader.push_dir(File.join(__dir__, '..', 'models'))
loader.push_dir(File.join(__dir__, '..', 'dtos'))
loader.setup
loader.eager_load

# --- Environment --------------------------------------------------------------

# Must be set before connecting: Database.connect picks the config section by env.
ENV['RUBY_ENV'] ||= 'development'

VERSION = '1.0.22'

# --- Database -----------------------------------------------------------------

Database.connect

db = ActiveRecord::Base.connection
db.execute('PRAGMA journal_mode=WAL')
db.execute('PRAGMA busy_timeout=5000')
