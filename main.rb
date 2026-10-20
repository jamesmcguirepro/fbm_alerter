# frozen_string_literal: true

# Docker captures stdout/stderr as pipes, which Ruby buffers by default. The
# scheduler is long-running, so without this its startup and "next run" logs
# would sit in the buffer instead of appearing in `docker compose logs`.
$stdout.sync = true
$stderr.sync = true

require_relative 'config/boot'

CLI.start(ARGV) if __FILE__ == $0
