# frozen_string_literal: true

require 'active_record'
require 'httparty'
require 'json'
require 'sqlite3'
require 'mail'
require 'dotenv/load'
# require 'zeitwerk'
# require_relative '../config/zeitwerk'
require_relative 'lib/config'
require_relative 'lib/database'
require_relative 'lib/socia_vault_client'
require_relative 'lib/email_service'
require_relative 'lib/monitor'
require_relative 'models/listing'

ENV['RUBY_ENV'] ||= 'development'
VERSION = '1.0.0'

Database.connect

monitor = Monitor.new

monitor.run_search