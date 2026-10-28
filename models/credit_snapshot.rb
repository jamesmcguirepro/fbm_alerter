# frozen_string_literal: true

# == Schema Information
#
# Table name: credit_snapshots
#
#  id            :integer          not null, primary key
#  balance       :decimal(12, 2)   not null
#  monitor_run_id:integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_credit_snapshots_on_monitor_run_id  (monitor_run_id)
#
class CreditSnapshot < ActiveRecord::Base
  belongs_to :monitor_run, optional: true

  # Capture the current credit balance from SociaVault.
  # @param monitor_run [MonitorRun, nil] the run this snapshot belongs to
  # @return [CreditSnapshot, nil] snapshot persisted, or nil on API error
  def self.capture(monitor_run: nil)
    balance = SociaVaultClient.credits['credits']
    return nil if balance.nil?

    create!(balance: balance, monitor_run: monitor_run)
  end

  # How many days of history do we keep (trims old rows on each capture).
  HISTORY_DAYS = 30
  private_constant :HISTORY_DAYS

  # Remove snapshots older than +HISTORY_DAYS+.
  def self.purge_old!
    where('created_at < ?', Time.current - HISTORY_DAYS.days).delete_all
  end

  # The lowest balance recorded over the last +HISTORY_DAYS+.
  # @return [Integer, nil]
  def self.lowest_recent
    recent.minimum(:balance)&.to_i
  end

  # The most recent balance recorded over the last +HISTORY_DAYS+.
  # @return [Integer, nil]
  def self.latest_recent
    recent.order(created_at: :desc).first&.balance&.to_i
  end

  # All snapshots in the last +HISTORY_DAYS+, ordered oldest first (for the
  # chart).
  def self.chart_data
    recent.order(created_at: :asc).pluck(:created_at, :balance)
  end

  # Snapshots within the history window.
  scope :recent, -> { where('created_at >= ?', Time.current - HISTORY_DAYS.days) }

  # Average daily credit consumption over the history window.
  # Returns nil when there are no snapshots.
  def self.average_daily_consumption
    snapshots = recent.order(created_at: :asc)
    return nil if snapshots.empty?

    first = snapshots.first
    last = snapshots.last
    days = [1, (last.created_at - first.created_at).to_f / 86400].max

    ((first.balance - last.balance) / days).round(2)
  end

  # Days until credits run out based on average daily consumption.
  # Returns nil when there is no consumption trend (balance is flat or growing).
  def self.days_remaining
    consumption = average_daily_consumption
    return nil if consumption.nil? || consumption <= 0

    latest = latest_recent
    return nil if latest.nil?

    (latest / consumption).round(1)
  end
end
