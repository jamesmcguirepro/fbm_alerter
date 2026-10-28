# syntax=docker/dockerfile:1
FROM ruby:4.0.6-slim

# Skip gem documentation to save space
RUN echo 'gem: --no-document' > /etc/gemrc

WORKDIR /app

# Install gems. The `date` gem (a dependency of mail → net-imap) has no
# precompiled binary for aarch64-linux, so build tools are needed at build
# time. They are installed, used, then purged in the same RUN layer so they
# do not bloat the final image. At runtime only libsqlite3-0 is required.
COPY Gemfile Gemfile.lock ./
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libsqlite3-dev \
      pkg-config \
    && gem install bundler \
    && bundle config set --local without 'development test' \
    && bundle install \
    && apt-get purge -y --auto-remove \
      build-essential \
      libsqlite3-dev \
      pkg-config \
    && apt-get install -y --no-install-recommends libsqlite3-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy the application code
COPY . .

ENV RUBY_ENV=development
ENV PORT=9292

# Ensure required directories exist
RUN mkdir -p /app/storage /app/tmp/pids /app/log && chmod +x /app/docker-entrypoint.sh

EXPOSE 9292

# curl is not installed; use Ruby's net/http for the health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ruby -e "require 'net/http'; require 'uri'; exit(Net::HTTP.get_response(URI('http://localhost:9292/health')).code == '200' ? 0 : 1)"

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["exec"]
