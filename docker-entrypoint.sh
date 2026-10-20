#!/bin/bash
set -e

echo "🚀 Marketplace Monitor container starting..."

# Only the web service migrates the database. The scheduler and one-shot tools
# wait for web to be healthy, so two containers never race on schema_migrations.
if [ "$1" = "web" ]; then
  echo "📦 Running database migrations..."
  bundle exec rake db:migrate
fi

# Validate configuration
echo "✅ Validating configuration..."
bundle exec ruby -e "require 'socket'; require 'dotenv/load'; require_relative 'lib/config'; Config.validate!; puts \"Configuration valid (date_listed=#{Config.date_listed}, schedule_at=#{Config.schedule_at}, host=#{Socket.gethostname})\""

# Dispatch command
case "$1" in
  web)
    echo "🌐 Starting web GUI on port ${PORT:-9292}..."
    exec bundle exec puma -b tcp://0.0.0.0:${PORT:-9292} config.ru
    ;;
  *)
    echo "🎯 Running command: $*"
    exec bundle exec ruby main.rb "$@"
    ;;
esac
