# frozen_string_literal: true

require 'active_record'

# SQLite database operations and management
class Database
  class << self
    def connect
      db_config = YAML.load_file('config/database.yml')

      env = ENV['RUBY_ENV']

      ActiveRecord::Base.establish_connection(db_config[env])
    end
  end
end
