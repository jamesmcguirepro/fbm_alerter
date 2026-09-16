# frozen_string_literal: true

require 'active_record'
require 'dotenv/load'
require 'httparty'
require 'json'
require 'mail'
require 'sqlite3'
# require 'zeitwerk'
# require_relative '../config/zeitwerk'
require_relative 'lib/config'
require_relative 'lib/database'
require_relative 'lib/email_service'
require_relative 'lib/search_object'
require_relative 'lib/socia_vault_client'
require_relative 'lib/monitor'

require_relative 'models/alert'
require_relative 'models/saved_search'
require_relative 'models/listing'

ENV['RUBY_ENV'] ||= 'development'
VERSION = '1.0.0'

Database.connect

# monitor = Monitor.new

# monitor.run_search

def main
  options = parse_options
  app = Monitor.new

  case
  when options[:add]
    # TODO: wire up
    search = options[:add].except(:email)
    email = options[:add][:email]

    app.add_saved_search(search:, email:)

  when options[:search]
    app.search(query: options[:search])

  when options[:delete]
    app.remove_saved_search(options[:delete])

  when options[:list]
    app.list_saved_searches
  end

rescue OptionParser::InvalidOption => e
  warn e.message
  exit 1
end

def parse_options
  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: ruby main.rb [options]'

    opts.on('-aQUERY', '--add=QUERY', 'Adds saved search') do |a|
      options[:add] = a
    end

    opts.on('-e', '--execute', 'Executes all saved searches') do |e|
      options[:execute] = e
    end

    opts.on('-l', '--list', 'Lists all saved searches') do |l|
      options[:list] = l
    end

    opts.on('-rID', '--remove=ID', 'Removes saved search by ID') do |r|
      options[:remove] = r
    end

    opts.on('-sQUERY', '--search=QUERY', 'One-time search, to stdout (no emails)') do |s|
      options[:search] = s
    end

    opts.on('-h', --'help', 'Show this message') do
      puts opts
      exit 0
    end
  end.parse!(ARGV)

  options
end

main if __FILE__ == $0
