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
    echo "  - SEARCHES (query|lat|lng|min|max format)"
    echo ""
    echo "Opening .env in editor..."
    ${EDITOR:-nano} .env
else
    echo "✓ .env file exists"
fi

echo ""
echo "Initializing database..."
bundle exec rake db:init
echo "✓ Database initialized"
echo ""

echo "Validating configuration..."
bundle exec rake config:validate
echo ""

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Review and verify .env settings"
echo "  2. Test with: bundle exec rake monitor:run"
echo "  3. For continuous monitoring: bundle exec rake monitor:daemon"
echo "  4. View database stats: bundle exec rake db:stats"
echo "  5. For cron scheduling, add to crontab:"
echo "     */30 * * * * cd $(pwd) && bundle exec rake monitor:run"
echo ""
