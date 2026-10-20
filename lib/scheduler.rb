# frozen_string_literal: true

# Runs all saved searches once a day at a configured local time. Unlike a
# shell loop that runs on container start, a restart only runs when the day's
# pass was genuinely missed: the last full pass is read from monitor_runs.
class Scheduler
  # How often to re-check the clock and database. Short enough to run close to
  # the scheduled minute and to notice a manual "Run all" while sleeping.
  POLL_INTERVAL = 60

  def initialize(io: $stdout, now: -> { Time.now }, sleeper: ->(seconds) { Kernel.sleep(seconds) })
    @io = io
    @now = now
    @sleeper = sleeper
  end

  def run
    @io.puts "⏰ Scheduler started — daily run at #{Config.schedule_at} #{zone_label}"

    loop do
      target = next_run_at
      wait = target - @now.call

      if wait.positive?
        log_wait(target, wait)
        @sleeper.call([wait, POLL_INTERVAL].min)
        next
      end

      run_all
    end
  end

  # When the next full pass is due. A time in the past means "run now".
  def next_run_at
    now = @now.call
    today = scheduled_time(now.to_date)

    # A full pass has already happened today (scheduled or manual), so the next
    # one is tomorrow. This is what makes a restart safe.
    return scheduled_time(now.to_date + 1) if ran_today?(now)

    now >= today ? now : today
  end

  private

  def scheduled_time(date)
    hour, minute = Config.schedule_at.split(':').map(&:to_i)
    Time.local(date.year, date.month, date.day, hour, minute)
  end

  def ran_today?(now)
    last = last_full_run_at
    return false if last.nil?

    last.getlocal.to_date == now.to_date
  end

  # Before 1.0.10 only per-search runs were recorded. Until the first new full
  # run exists, fall back to the latest search_run so upgrading does not repeat
  # a search that has already run today. Once a monitor_run exists, single-search
  # runs are ignored again.
  def last_full_run_at
    last = MonitorRun.maximum(:started_at)
    return last if last
    return nil unless MonitorRun.none?

    SearchRun.maximum(:created_at)
  end

  def run_all
    @io.puts "\n⏰ Daily run starting at #{@now.call}..."
    MarketplaceMonitor.new(io: @io).execute_saved_searches(initiated_by: 'scheduler')
  rescue StandardError => e
    @io.puts "✗ Scheduled run failed: #{e.message}"
    @sleeper.call(POLL_INTERVAL)
  end

  def log_wait(target, wait)
    return if @logged_target == target

    @logged_target = target
    @io.puts "⏳ Next run: #{target.strftime('%b %d, %Y %I:%M %p %Z')} (in #{humanize(wait)})"
  end

  def humanize(seconds)
    hours, remainder = seconds.round.divmod(3600)
    minutes, = remainder.divmod(60)

    parts = []
    parts << "#{hours}h" if hours.positive?
    parts << "#{minutes}m" if minutes.positive? || parts.empty?
    parts.join(' ')
  end

  def zone_label
    @now.call.strftime('%Z')
  end
end
