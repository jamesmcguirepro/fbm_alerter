#!/bin/bash
set -e

# Wait for any dependencies (none for SQLite, but keep pattern for extensibility)
echo "🚀 Marketplace Monitor container starting..."

# Run database migrations
echo "📦 Running database migrations..."
bundle exec rake db:migrate

# Validate configuration
echo "✅ Validating configuration..."
bundle exec ruby -e "require 'dotenv/load'; require_relative 'lib/config'; Config.validate!; puts 'Configuration valid'"

echo "🎯 Running command: $*"
exec bundle exec ruby main.rb "$@"
