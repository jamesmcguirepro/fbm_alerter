# frozen_string_literal: true

class CLI < Thor
  desc 'schedule', 'Run all saved searches daily at SCHEDULE_AT'
  def schedule
    Scheduler.new.run
  end

  def self.exit_on_failure?
    true
  end
end
