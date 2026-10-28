# frozen_string_literal: true

# Puma configuration for FBM Alerter.
# This file is intentionally minimal; the web runs single-threaded on NAS.
# Override defaults via CLI flags (script/server -p 4567) or environment variables.

max_threads_count = 1
min_threads_count = 1
threads min_threads_count, max_threads_count

port        ENV.fetch('PORT', '9292')
bind        "tcp://0.0.0.0:#{ENV.fetch('PORT', '9292')}"

environment ENV.fetch('RUBY_ENV', 'development')

# Single worker — the app is not multi-threaded.
workers ENV.fetch('WEB_CONCURRENCY', 0).to_i

# Log to stdout (container-friendly).
stdout_redirect 'log/stdout.log', 'log/stderr.log', true

# PID file for process management.
pidfile 'tmp/pids/puma.pid'
state_path  'tmp/pids/puma.state'
