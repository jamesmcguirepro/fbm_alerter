# frozen_string_literal: true

require 'active_record'
require 'active_record/schema_dumper'
require 'yaml'
require 'erb'

# 1. Load DB configuration
db_config = YAML.safe_load(
  ERB.new(File.read('config/database.yml')).result,
  aliases: true
)

env = ENV['RUBY_ENV'] || 'development'

# 2. Configure ActiveRecord DatabaseTasks
ActiveRecord::Tasks::DatabaseTasks.env = env
ActiveRecord::Tasks::DatabaseTasks.database_configuration = db_config
ActiveRecord::Tasks::DatabaseTasks.db_dir = 'db'
ActiveRecord::Tasks::DatabaseTasks.migrations_paths = ['db/migrate']

# Connect ActiveRecord to the database
ActiveRecord::Base.establish_connection(db_config[env])

# 3. Define the db namespace tasks
namespace :db do
  desc 'Migrate the database'
  task :migrate do
    ActiveRecord::Base.connection_pool.migration_context.migrate
    puts 'Database migrated successfully.'
  end

  desc 'Rollback the database'
  task :rollback do
    ActiveRecord::Base.connection_pool.migration_context.rollback
    puts 'Database rolled back.'
  end

  desc 'Display status of migrations'
  task :status do
    migrations = ActiveRecord::Base.connection_pool.migration_context.migrations_status
    puts "\ndb/migrate status:"
    puts '   Status   Migration ID    Migration Name'
    puts '-' * 50
    migrations.each do |status, version, name|
      puts "   #{status.ljust(8)} #{version}  #{name}"
    end
    puts
  end
end
