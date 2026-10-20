# frozen_string_literal: true

# == Schema Information
#
# Table name: monitor_runs
#
#  id           :integer          not null, primary key
#  finished_at  :datetime
#  initiated_by :string           not null
#  started_at   :datetime         not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_monitor_runs_on_started_at  (started_at)
#
class MonitorRun < ActiveRecord::Base
  validates :started_at, presence: true
  validates :initiated_by, presence: true

  # Record the start of one full pass over all saved searches. Recording the
  # start (rather than only the finish) means an interrupted run still counts,
  # so restarting the scheduler does not immediately spend the same credits
  # again.
  # @param initiated_by [String] scheduler, gui or cli
  # @return [MonitorRun]
  def self.start!(initiated_by:)
    create!(started_at: Time.current, initiated_by: initiated_by.to_s)
  end

  def finish!
    update!(finished_at: Time.current)
  end
end
