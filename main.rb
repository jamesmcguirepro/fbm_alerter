# frozen_string_literal: true

# Require our monitor before ActiveRecord loads Ruby's stdlib Monitor,
# which would otherwise conflict with our class name.
require_relative 'lib/monitor'

require 'active_record'
require 'dotenv/load'
require 'httparty'
require 'json'
require 'mail'
require 'sqlite3'
require 'thor'
require 'zeitwerk'

require_relative 'config/zeitwerk'

ENV['RUBY_ENV'] ||= 'development'
VERSION = '1.0.0'

Database.connect

def main
  CLI.start(ARGV)
end

main if __FILE__ == $0
