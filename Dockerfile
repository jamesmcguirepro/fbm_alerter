# syntax=docker/dockerfile:1
FROM ruby:4.0.6-slim

# Install system dependencies for native gems (sqlite3, etc.)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libsqlite3-dev \
      pkg-config \
      git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install bundler first
RUN gem install bundler

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle install

# Copy the application code
COPY . .

# Database path default
ENV DB_PATH=/data/marketplace_monitor.db
ENV RUBY_ENV=development

# Ensure data directory exists for sqlite
RUN mkdir -p /data && chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["exec"]
