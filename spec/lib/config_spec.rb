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

  describe '.instance_name' do
    after { ENV.delete('INSTANCE_NAME') }

    it 'uses INSTANCE_NAME when set' do
      ENV['INSTANCE_NAME'] = 'james-nas'
      expect(described_class.instance_name).to eq('james-nas')
    end

    it 'ignores surrounding whitespace' do
      ENV['INSTANCE_NAME'] = '  james-nas  '
      expect(described_class.instance_name).to eq('james-nas')
    end

    it 'treats a blank name as unset' do
      ENV['INSTANCE_NAME'] = '   '
      expect(described_class.instance_name).to eq(Socket.gethostname)
    end

    it 'falls back to the machine hostname' do
      ENV.delete('INSTANCE_NAME')
      expect(described_class.instance_name).to eq(Socket.gethostname)
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
