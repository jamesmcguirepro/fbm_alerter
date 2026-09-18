# frozen_string_literal: true

require 'active_record'
require 'dotenv/load'
require 'httparty'
require 'json'
require 'mail'
require 'sqlite3'
# require 'zeitwerk'
# require_relative '../config/zeitwerk'
require_relative 'dtos/listing_object'
require_relative 'dtos/search_object'

require_relative 'lib/cli'
require_relative 'lib/config'
require_relative 'lib/database'
require_relative 'lib/email_service'
require_relative 'lib/socia_vault_client'
require_relative 'lib/monitor'

require_relative 'models/alert'
require_relative 'models/saved_search'
require_relative 'models/listing'

ENV['RUBY_ENV'] ||= 'development'
VERSION = '1.0.0'

Database.connect

def main
  CLI.start(ARGV)
end

main if __FILE__ == $0
