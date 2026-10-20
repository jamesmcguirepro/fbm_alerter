# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MonitorRun do
  describe '.start!' do
    it 'records the start and who initiated it' do
      Timecop.freeze(Time.local(2026, 10, 19, 20, 0, 0)) do
        run = described_class.start!(initiated_by: 'scheduler')

        expect(run.started_at).to be_within(1).of(Time.now)
        expect(run.finished_at).to be_nil
        expect(run.initiated_by).to eq('scheduler')
      end
    end
  end

  describe '#finish!' do
    it 'stamps the finish time' do
      run = described_class.start!(initiated_by: 'cli')
      later = Time.now + 5

      Timecop.freeze(later) { run.finish! }

      expect(run.reload.finished_at).to be_within(1).of(later)
    end
  end
end
