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

  describe '.parse_interval' do
    it 'parses minutes' do
      expect(described_class.parse_interval('30m')).to eq(1800)
    end

    it 'parses hours' do
      expect(described_class.parse_interval('2h')).to eq(7200)
    end

    it 'parses days' do
      expect(described_class.parse_interval('1d')).to eq(86_400)
    end

    it 'returns default for invalid format' do
      expect(described_class.parse_interval('invalid')).to eq(1800)
    end

    it 'handles single digit times' do
      expect(described_class.parse_interval('1m')).to eq(60)
      expect(described_class.parse_interval('1h')).to eq(3600)
      expect(described_class.parse_interval('1d')).to eq(86_400)
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
