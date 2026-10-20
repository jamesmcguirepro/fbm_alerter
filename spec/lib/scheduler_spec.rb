# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Scheduler do
  subject(:scheduler) { described_class.new(io: StringIO.new, now: -> { Time.now }) }

  after { Timecop.return }

  def freeze_at(hour, minute = 0)
    Timecop.freeze(Time.local(2026, 10, 19, hour, minute, 0))
  end

  def full_run_at(time)
    MonitorRun.create!(started_at: time, initiated_by: 'scheduler')
  end

  describe '#next_run_at' do
    it 'waits for the scheduled time when the last full run was yesterday' do
      freeze_at(19)
      full_run_at(Time.local(2026, 10, 18, 20, 0))

      expect(scheduler.next_run_at).to eq(Time.local(2026, 10, 19, 20, 0))
    end

    it 'waits for the scheduled time on a brand-new database' do
      freeze_at(19)

      expect(scheduler.next_run_at).to eq(Time.local(2026, 10, 19, 20, 0))
    end

    it 'catches up immediately when today 20:00 was missed' do
      freeze_at(21)
      full_run_at(Time.local(2026, 10, 18, 20, 0))

      expect(scheduler.next_run_at).to eq(Time.now)
    end

    it 'runs immediately on a brand-new database after the scheduled time' do
      freeze_at(21)

      expect(scheduler.next_run_at).to eq(Time.now)
    end

    it 'does not run again after a full run already happened today' do
      freeze_at(21)
      full_run_at(Time.local(2026, 10, 19, 20, 0))

      expect(scheduler.next_run_at).to eq(Time.local(2026, 10, 20, 20, 0))
    end

    it 'treats an earlier manual full run as today’s run' do
      freeze_at(10)
      full_run_at(Time.local(2026, 10, 19, 9, 0))

      expect(scheduler.next_run_at).to eq(Time.local(2026, 10, 20, 20, 0))
    end

    it 'ignores a single-search run once a full run has been recorded' do
      freeze_at(21)
      full_run_at(Time.local(2026, 10, 18, 20, 0))
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      SearchRun.create!(saved_search_id: search.id, success: true)

      expect(scheduler.next_run_at).to eq(Time.now)
    end

    it 'falls back to the legacy search history on the first 1.0.10 start' do
      freeze_at(21)
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      SearchRun.create!(
        saved_search_id: search.id, success: true,
        created_at: Time.local(2026, 10, 19, 20, 0)
      )

      expect(scheduler.next_run_at).to eq(Time.local(2026, 10, 20, 20, 0))
    end

    it 'uses SCHEDULE_AT when it is not the default' do
      freeze_at(7)
      full_run_at(Time.local(2026, 10, 18, 8, 0))
      allow(Config).to receive(:schedule_at).and_return('08:00')

      expect(scheduler.next_run_at).to eq(Time.local(2026, 10, 19, 8, 0))
    end

    it 'crosses a DST boundary at the same wall-clock time' do
      # 2026-03-08 is the US spring-forward day.
      Timecop.freeze(Time.local(2026, 3, 7, 21, 0, 0))
      full_run_at(Time.local(2026, 3, 7, 20, 0))

      expect(scheduler.next_run_at).to eq(Time.local(2026, 3, 8, 20, 0))
    end
  end

  describe '#run' do
    it 'passes the scheduler source to the full run' do
      monitor = instance_double(MarketplaceMonitor)
      allow(MarketplaceMonitor).to receive(:new).with(io: anything).and_return(monitor)
      expect(monitor).to receive(:execute_saved_searches).with(initiated_by: 'scheduler')

      scheduler.send(:run_all)
    end
  end
end
