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
    let(:call) { described_class.send_alerts(listings:, emails:, query: 'bike') }
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
          listed_at: Time.now,
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

    it 'names the search query and count in the subject' do
      call

      expect(mailer).to have_received(:send_email).with(hash_including(subject: '🔔 1 new listing for "bike"')).once
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
            listed_at: Time.now,
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
            listed_at: Time.now,
            first_seen_at: Time.now
          )
        ]
      end

      it 'pluralises the subject count' do
        call

        expect(mailer).to have_received(:send_email).with(hash_including(subject: '🔔 2 new listings for "bike"')).once
      end

      it 'alternates the row background colours' do
        call

        expect(mailer).to have_received(:send_email) do |args|
          expect(args[:html_body]).to include('class="listing alt"')
        end
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
        expect(html_body).to start_with('<!DOCTYPE html>')
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

    it 'names the deployment that sent it' do
      allow(Config).to receive(:instance_name).and_return('james-nas')

      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).to include('Sent by james-nas')
      end
    end

    it 'escapes the deployment name' do
      allow(Config).to receive(:instance_name).and_return('nas & <b>nas</b>')

      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).to include('Sent by nas &amp; &lt;b&gt;nas&lt;/b&gt;')
      end
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

    it 'makes the whole card link to the ad' do
      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).to include(
          '<a class="listing" href="https://facebook.com/marketplace/item/123/" target="_blank">'
        )
      end
    end

    it 'shows the search query in the header' do
      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).to include('<h1>bike</h1>')
      end
    end

    it 'does not label each listing with the query' do
      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).not_to include('class="query"')
      end
    end

    it 'has no dedicated open button' do
      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).not_to include('View Listing')
      end
    end

    it 'escapes HTML in listing text' do
      allow(listings.first).to receive(:title).and_return('Bike & <Parts>')

      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).to include('Bike &amp; &lt;Parts&gt;')
        expect(args[:html_body]).not_to include('<Parts>')
      end
    end

    it 'shows when the ad was listed' do
      allow(listings.first).to receive(:listed_at).and_return(Time.new(2026, 10, 16, 9, 30))

      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).to include('Listed: Oct 16, 2026')
      end
    end

    it 'labels the first-seen date when the listing date is unknown' do
      allow(listings.first).to receive(:listed_at).and_return(nil)
      allow(listings.first).to receive(:first_seen_at).and_return(Time.new(2026, 10, 16, 9, 30))

      call

      expect(mailer).to have_received(:send_email) do |args|
        expect(args[:html_body]).to include('First seen: Oct 16, 2026')
        expect(args[:html_body]).not_to include('Listed:')
      end
    end

    context 'when location is blank' do
      before { allow(listings.first).to receive(:location).and_return(nil) }

      it 'omits the location line' do
        call

        expect(mailer).to have_received(:send_email) do |args|
          expect(args[:html_body]).not_to include('📍')
        end
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

  describe '.render' do
    it 'builds standalone HTML without sending mail' do
      html = described_class.render(listings: [], query: 'bike')

      expect(html).to start_with('<!DOCTYPE html>')
      expect(html.strip).to end_with('</html>')
      expect(mailer).not_to have_received(:send_email)
    end
  end
end
