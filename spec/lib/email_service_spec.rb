# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/email_service'

RSpec.describe EmailService do
  let(:mailer) do
    class_double("Mailer", send_email: nil)
  end

  before do
    stub_const("Mailer", mailer)
  end

  describe '.send_alerts' do
    let(:call) { described_class.send_alerts(listings:, emails:) }
    let(:listings) do
      [
        instance_double(
          ListingObject,
          title: 'Mountain Bike',
          price: 250,
          location: 'Austin, TX',
          url: 'https://facebook.com/marketplace/item/123/',
          image_url: 'https://example.com/photo.jpg',
          search_query: 'bike',
          first_seen_at: Time.now
        )
      ]
    end
    let(:emails) {[ 'test@test.com' ]}


    context 'when listings are empty' do
      let(:listings) { [] }

      it 'sends nothing' do
        call

        expect(mailer).to have_received(:send_email).exactly(0).times
      end
    end

    context 'with multiple recipients' do
      let(:emails) { %w[test@test.com test2@test.com test3@test.com] }

      it 'sends to each recipient' do
        call

        expect(mailer).to have_received(:send_email).with(hash_including(to: emails[0])).once
        expect(mailer).to have_received(:send_email).with(hash_including(to: emails[1])).once
        expect(mailer).to have_received(:send_email).with(hash_including(to: emails[2])).once
      end
    end

    it 'subject includes count' do
      call

      expect(mailer).to have_received(:send_email).with(hash_including(subject: '🔔 1 New Marketplace Listing(s)')).once
    end

    context 'with multiple listings returned' do
      let(:listings) do
        [
          instance_double(
            ListingObject,
            title: 'Mountain Bike',
            price: 250,
            location: 'Austin, TX',
            url: 'https://facebook.com/marketplace/item/123/',
            image_url: 'https://example.com/photo.jpg',
            search_query: 'bike',
            first_seen_at: Time.now
          ),
          instance_double(
            ListingObject,
            title: 'Mountain Bike 2',
            price: 250,
            location: 'Austin, TX',
            url: 'https://facebook.com/marketplace/item/123/',
            image_url: 'https://example.com/photo.jpg',
            search_query: 'bike',
            first_seen_at: Time.now
          )
        ]
      end

      it 'subject includes count for multiple listings' do
        call

        expect(mailer).to have_received(:send_email).with(hash_including(subject: '🔔 2 New Marketplace Listing(s)')).once
      end
    end

    it 'includes responsive design classes' do
      call
      expect(mailer).
        to have_received(:send_email).
        with(hash_including(html_body: a_string_including("class=", "container"))).
        once
    end

    it 'wraps content in HTML tags' do
      call

      expect(mailer).to have_received(:send_email) do |args|
        html_body = args[:html_body]
        expect(html_body).to include("class=", "container")
        expect(html_body).to start_with('<html>')
        expect(html_body.strip).to end_with('</html>')
      end
    end

    it 'includes footer with branding' do
      call

      expect(mailer).
        to have_received(:send_email).
        with(hash_including(html_body: a_string_including("Marketplace Monitor • Automated Email Alert"))).
        once
    end

    it 'includes all listing details in HTML body' do
      call

      expect(mailer).to have_received(:send_email) do |args|
        html_body = args[:html_body]
        expect(html_body).to include(
                               'Mountain Bike',
                               '250',
                               'Austin, TX',
                               'https://facebook.com/marketplace/item/123/',
                               'https://example.com/photo.jpg',
                               'bike'
                             )
      end
    end

    context 'when image URL is nil' do
      before { allow(listings.first).to receive(:image_url).and_return(nil) }

      it 'does not include img tag' do
        call

        expect(mailer).to have_received(:send_email) do |args|
          expect(args[:html_body]).not_to include('<img')
        end
      end
    end

    context 'when price is missing' do
      before { allow(listings.first).to receive(:price).and_return(nil) }

      it 'displays N/A for price' do
        call

        expect(mailer).to have_received(:send_email) do |args|
          expect(args[:html_body]).to include('N/A')
        end
      end
    end

    context 'when deliver raises an error' do
      it 'handles delivery errors gracefully' do
        allow(Mail).to receive(:new) do |&block|
          mail = double('Mail::Message')
          allow(mail).to receive(:deliver!).and_raise('SMTP Error')
          block.call(mail) if block
          mail
        end

        expect { call }.not_to raise_error
      end
    end
  end
end
