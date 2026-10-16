#!/bin/bash

# Marketplace Monitor Setup Script
# This script helps you set up the marketplace monitor

set -e

echo "🚀 Marketplace Monitor Setup"
echo "============================"
echo ""

# Check Ruby version
echo "Checking Ruby version..."
RUBY_VERSION=$(ruby -v)
echo "✓ $RUBY_VERSION"
echo ""

# Check if bundler is installed
if ! command -v bundle &> /dev/null; then
    echo "Installing bundler..."
    gem install bundler
fi

# Install gems
echo "Installing dependencies..."
bundle install
echo "✓ Gems installed"
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo "📋 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  IMPORTANT: Edit .env with your configuration!"
    echo ""
    echo "Required settings:"
    echo "  - SOCIAVAULT_API_KEY (from https://sociavault.com/dashboard)"
    echo "  - EMAIL_FROM and EMAIL_TO"
    echo "  - SMTP settings (Gmail recommended)"
    echo ""
    echo "Opening .env in editor..."
    ${EDITOR:-nano} .env
else
    echo "✓ .env file exists"
fi

echo ""
echo "Initializing database..."
bundle exec rake db:migrate
echo "✓ Database migrated"
echo ""

echo "Validating configuration..."
bundle exec ruby -e "require 'dotenv/load'; require_relative 'lib/config'; Config.validate!; puts '✓ Configuration valid'"
echo ""

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Review and verify .env settings"
echo "  2. Add a saved search:"
echo "     bundle exec ruby main.rb add -q bike -lat 30.2677 -long -97.7475 --min 100 --max 500 --email you@example.com"
echo "  3. List saved searches:  bundle exec ruby main.rb list"
echo "  4. Run all saved searches: bundle exec ruby main.rb exec"
echo "  5. After migrations, re-annotate models:"
echo "     RUBYOPT='-I. -r./main.rb' bundle exec annotaterb models --model-dir models --ignore-unknown-models"
echo "  6. For cron scheduling, add to crontab:"
echo "     */30 * * * * cd $(pwd) && bundle exec ruby main.rb exec"
echo ""
