# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Config do
  describe '.api_key' do
    it 'returns API key from environment' do
      expect(described_class.api_key).to eq('sk_test_key')
    end

    it 'raises error when not set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('SOCIAVAULT_API_KEY').and_return(nil)
      expect { described_class.api_key }.to raise_error(RuntimeError, /SOCIAVAULT_API_KEY not set/)
    end
  end

  describe '.email_from' do
    it 'returns sender email' do
      expect(described_class.email_from).to eq('test@example.com')
    end

    it 'returns default when not set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('EMAIL_FROM').and_return(nil)
      expect(described_class.email_from).to eq('marketplace-alerts@example.com')
    end
  end

  describe '.smtp_address' do
    it 'returns SMTP address from environment' do
      expect(described_class.smtp_address).to eq('smtp.gmail.com')
    end

    it 'returns default when not set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('SMTP_ADDRESS').and_return(nil)
      expect(described_class.smtp_address).to eq('smtp.gmail.com')
    end
  end

  describe '.smtp_port' do
    it 'returns port as integer' do
      expect(described_class.smtp_port).to eq(587)
    end

    it 'converts string to integer' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('SMTP_PORT').and_return('25')
      expect(described_class.smtp_port).to eq(25)
    end

    it 'returns default when not set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('SMTP_PORT').and_return(nil)
      expect(described_class.smtp_port).to eq(587)
    end
  end

  describe '.dry_run?' do
    after { ENV.delete('DRY_RUN') }

    it 'is off when unset' do
      ENV.delete('DRY_RUN')
      expect(described_class.dry_run?).to be(false)
    end

    it 'turns on for true' do
      ENV['DRY_RUN'] = 'true'
      expect(described_class.dry_run?).to be(true)
    end

    it 'turns on for TRUE too' do
      ENV['DRY_RUN'] = 'TRUE'
      expect(described_class.dry_run?).to be(true)
    end

    it 'is off for false' do
      ENV['DRY_RUN'] = 'false'
      expect(described_class.dry_run?).to be(false)
    end

    it 'tolerates 1 and 0 as well' do
      ENV['DRY_RUN'] = '1'
      expect(described_class.dry_run?).to be(true)

      ENV['DRY_RUN'] = '0'
      expect(described_class.dry_run?).to be(false)
    end

    it 'treats anything else as off' do
      ENV['DRY_RUN'] = 'maybe'
      expect(described_class.dry_run?).to be(false)
    end
  end

  describe '.date_listed' do
    after { ENV.delete('DATE_LISTED') }

    it 'defaults to the last 7 days when unset' do
      ENV.delete('DATE_LISTED')
      expect(described_class.date_listed).to eq('last_7_days')
    end

    it 'defaults when set to blank' do
      ENV['DATE_LISTED'] = '  '
      expect(described_class.date_listed).to eq('last_7_days')
    end

    it 'accepts every window SociaVault documents' do
      %w[all 1 7 30 last_24_hours last_7_days last_30_days].each do |value|
        ENV['DATE_LISTED'] = value
        expect(described_class.date_listed).to eq(value)
      end
    end

    it 'ignores surrounding whitespace' do
      ENV['DATE_LISTED'] = ' last_30_days '
      expect(described_class.date_listed).to eq('last_30_days')
    end

    it 'warns and falls back when the window is not one the API knows' do
      ENV['DATE_LISTED'] = 'last_2_days'

      expect { described_class.date_listed }
        .to output(/DATE_LISTED="last_2_days" is not a SociaVault window/).to_stderr
      expect(described_class.date_listed).to eq('last_7_days')
    end
  end

  describe '.schedule_at' do
    after { ENV.delete('SCHEDULE_AT') }

    it 'defaults to 20:00 when unset' do
      ENV.delete('SCHEDULE_AT')
      expect(described_class.schedule_at).to eq('20:00')
    end

    it 'defaults when set to blank' do
      ENV['SCHEDULE_AT'] = '  '
      expect(described_class.schedule_at).to eq('20:00')
    end

    it 'accepts a 24-hour time' do
      ENV['SCHEDULE_AT'] = '23:59'
      expect(described_class.schedule_at).to eq('23:59')
    end

    it 'normalizes a single-digit hour' do
      ENV['SCHEDULE_AT'] = '8:05'
      expect(described_class.schedule_at).to eq('08:05')
    end

    it 'ignores surrounding whitespace' do
      ENV['SCHEDULE_AT'] = ' 07:30 '
      expect(described_class.schedule_at).to eq('07:30')
    end

    it 'warns and falls back for an invalid time' do
      ENV['SCHEDULE_AT'] = '8pm'

      expect { @result = described_class.schedule_at }
        .to output(/SCHEDULE_AT="8pm" is not a valid HH:MM time/).to_stderr
      expect(@result).to eq('20:00')
    end

    it 'warns and falls back for an out-of-range time' do
      ENV['SCHEDULE_AT'] = '24:00'

      expect { @result = described_class.schedule_at }
        .to output(/SCHEDULE_AT="24:00" is not a valid HH:MM time/).to_stderr
      expect(@result).to eq('20:00')
    end
  end

  describe '.nominatim_url' do
    after { ENV.delete('NOMINATIM_URL') }

    it 'defaults to the public service' do
      ENV.delete('NOMINATIM_URL')
      expect(described_class.nominatim_url).to eq('https://nominatim.openstreetmap.org')
    end

    it 'treats a blank value as unset' do
      ENV['NOMINATIM_URL'] = '  '
      expect(described_class.nominatim_url).to eq('https://nominatim.openstreetmap.org')
    end

    it 'uses a configured endpoint and strips trailing slashes' do
      ENV['NOMINATIM_URL'] = 'https://geo.example.com/nominatim/'
      expect(described_class.nominatim_url).to eq('https://geo.example.com/nominatim')
    end
  end

  describe '.validate!' do
    it 'passes when all required vars are set' do
      expect { described_class.validate! }.not_to raise_error
    end

    it 'raises error when API key is missing' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('SOCIAVAULT_API_KEY').and_return(nil)
      expect { described_class.validate! }.to raise_error
    end
  end
end
