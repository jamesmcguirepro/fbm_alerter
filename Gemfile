source 'https://rubygems.org'

ruby '3.4.4'

gem 'activerecord', '~> 8.1.3'
gem 'chronic_duration', '~> 0.10.6' # Parse duration strings like "30m"
gem 'dotenv', '~> 2.8.1'          # Environment variable management
gem 'httparty', '~> 0.22.0'       # HTTP client for API requests
gem 'mail', '~> 2.8.1'            # Email sending library
gem 'rake', '~> 10.4.2'
gem 'sqlite3', '~> 2.1.0'         # SQLite database
gem 'whenever', '~> 1.0.0'        # Cron scheduling helper (optional)
gem 'zeitwerk', '~> 2.6.0'

group :development, :test do
  # Gemfile
  # gem 'annotate', '~> 3.2'
  gem 'database_cleaner-active_record'
  gem 'rspec', '~> 3.13.0'        # Testing framework
  gem 'timecop', '~> 0.9.11'
end

group :development do
  gem 'pry', '~> 0.14.2'          # Interactive debugging
  gem 'rubocop', '~> 1.60.0'      # Code linting
end
