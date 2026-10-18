# syntax=docker/dockerfile:1
FROM ruby:4.0.6-slim

# Install system dependencies for native gems (sqlite3, etc.) and health checks
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libsqlite3-dev \
      pkg-config \
      git \
      curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install bundler first
RUN gem install bundler

# Copy Gemfile and install gems (runtime only; dev/test gems excluded)
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle install

# Copy the application code
COPY . .

ENV RUBY_ENV=development
ENV PORT=9292

# Ensure the SQLite storage directory exists
RUN mkdir -p /app/storage && chmod +x /app/docker-entrypoint.sh

EXPOSE 9292

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:9292/health || exit 1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["exec"]
