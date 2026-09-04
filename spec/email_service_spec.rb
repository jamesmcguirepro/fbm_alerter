# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/email_service'

RSpec.describe EmailService do
  describe '.configure_smtp' do
    it 'configures Mail gem with SMTP settings' do
      expect(Mail).to receive(:defaults).and_yield
      described_class.configure_smtp
    end

    it 'uses configured SMTP address' do
      config_mock = instance_double('Mail::Configuration')
      expect(Mail).to receive(:defaults).and_yield
      expect(Mail).to receive(:delivery_method).with(:smtp, hash_including(address: 'smtp.gmail.com'))

      described_class.configure_smtp
    end
  end

  describe '.send_alerts' do
    let(:listings) do
      [
        {
          'title' => 'Mountain Bike',
          'price' => 250,
          'location' => 'Austin, TX',
          'url' => 'https://facebook.com/marketplace/item/123/',
          'image_url' => 'https://example.com/photo.jpg',
          'search_query' => 'bike',
          'first_seen_at' => Time.now
        }
      ]
    end

    before do
      allow(described_class).to receive(:configure_smtp)
      allow_any_instance_of(Mail::Message).to receive(:deliver!)
    end

    it 'does nothing for empty listings' do
      expect_any_instance_of(Mail::Message).not_to receive(:deliver!)
      described_class.send_alerts([])
    end

    it 'sends email to each recipient' do
      recipients = ['user1@example.com', 'user2@example.com']
      allow(Config).to receive(:email_to).and_return(recipients)

      expect_any_instance_of(Mail::Message).to receive(:deliver!).twice
      described_class.send_alerts(listings)
    end

    it 'includes correct sender' do
      allow(Config).to receive(:email_from).and_return('alerts@example.com')

      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.from).to eq(['alerts@example.com'])
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes recipient' do
      allow(Config).to receive(:email_to).and_return(['recipient@example.com'])

      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.to).to eq(['recipient@example.com'])
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes subject with count' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.subject).to include('1 New Marketplace Listing')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes correct subject for multiple listings' do
      listings << listings[0].dup

      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.subject).to include('2 New Marketplace Listing')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'sets content type to HTML' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.content_type).to include('text/html')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes listing title in email' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).to include('Mountain Bike')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes listing price in email' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).to include('250')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes listing location in email' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).to include('Austin, TX')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes listing URL in email' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).to include('https://facebook.com/marketplace/item/123/')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes listing image in email' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).to include('https://example.com/photo.jpg')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'includes search query in email' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).to include('bike')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'handles delivery errors gracefully' do
      allow_any_instance_of(Mail::Message).to receive(:deliver!).and_raise('SMTP Error')
      expect { described_class.send_alerts(listings) }.not_to raise_error
    end

    it 'handles nil image_url' do
      listings[0]['image_url'] = nil

      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).not_to include('<img')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'handles missing price gracefully' do
      listings[0]['price'] = nil

      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).to include('N/A')
        mail
      end

      described_class.send_alerts(listings)
    end

    it 'sends to multiple recipients independently' do
      recipients = ['user1@example.com', 'user2@example.com', 'user3@example.com']
      allow(Config).to receive(:email_to).and_return(recipients)

      delivery_count = 0
      allow_any_instance_of(Mail::Message).to receive(:deliver!) { delivery_count += 1 }

      described_class.send_alerts(listings)
      expect(delivery_count).to eq(3)
    end
  end

  describe 'HTML email structure' do
    let(:listing) do
      {
        'title' => 'Test Item',
        'price' => 100,
        'location' => 'Test City',
        'url' => 'https://example.com',
        'image_url' => 'https://example.com/img.jpg',
        'search_query' => 'test',
        'first_seen_at' => '2024-01-01 12:00:00'
      }
    end

    before do
      allow(described_class).to receive(:configure_smtp)
      allow_any_instance_of(Mail::Message).to receive(:deliver!)
    end

    it 'includes responsive design classes' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        body = mail.html_part.body.encoded
        expect(body).to include('class=')
        expect(body).to include('container')
        mail
      end

      described_class.send_alerts([listing])
    end

    it 'includes footer with branding' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        expect(mail.html_part.body.encoded).to include('Marketplace Monitor')
        mail
      end

      described_class.send_alerts([listing])
    end

    it 'includes opening and closing HTML tags' do
      expect(Mail).to receive(:new) do |&block|
        mail = Mail.new
        block.call(mail)
        body = mail.html_part.body.encoded
        expect(body).to start_with('<html>')
        expect(body).to end_with('</html>')
        mail
      end

      described_class.send_alerts([listing])
    end
  end
end
