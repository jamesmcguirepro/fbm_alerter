# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/email_service'

RSpec.describe EmailService do
  before do
    allow(described_class).to receive(:configure_smtp)
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

    before { allow(Config).to receive(:email_to).and_return(['user@example.com']) }

    context 'when listings are empty' do
      it 'sends nothing' do
        described_class.send_alerts([])
      end
    end

    context 'with multiple recipients' do
      before do
        allow(Config).to receive(:email_to).and_return(['user1@example.com', 'user2@example.com', 'user3@example.com'])
      end

      it 'sends to each recipient' do
        mail_double = instance_double(Mail::Message)
        allow(mail_double).to receive(:deliver!)
        allow(Mail).to receive(:new).and_return(mail_double)

        described_class.send_alerts(listings)

        expect(Mail).to have_received(:new).exactly(3).times
      end
    end

    context 'email content' do
      before do
        allow(Mail).to receive(:new).and_call_original
        allow_any_instance_of(Mail::Message).to receive(:deliver!)
      end

      it 'subject includes count for single listing' do
        subject_line = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          subject_line = mail.subject
          mail
        end

        described_class.send_alerts(listings)
        expect(subject_line).to include('1 New Marketplace Listing')
      end

      it 'subject includes count for multiple listings' do
        subject_line = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          subject_line = mail.subject
          mail
        end

        described_class.send_alerts(listings + [listings[0].dup])
        expect(subject_line).to include('2 New Marketplace Listing')
      end

      it 'sets content type to HTML' do
        content_type = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          content_type = mail.html_part.content_type
          mail
        end

        described_class.send_alerts(listings)
        expect(content_type).to include('text/html')
      end

      it 'includes responsive design classes' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to include('class=')
        expect(body).to include('container')
      end

      it 'wraps content in HTML tags' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to start_with('<html>')
        expect(body.strip).to end_with('</html>')
      end

      it 'includes footer with branding' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to include('Marketplace Monitor')
      end

      it 'includes listing title' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to include('Mountain Bike')
      end

      it 'includes listing price' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to include('250')
      end

      it 'includes listing location' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to include('Austin, TX')
      end

      it 'includes listing URL' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to include('https://facebook.com/marketplace/item/123/')
      end

      it 'includes listing image' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to include('https://example.com/photo.jpg')
      end

      it 'includes search query' do
        body = nil
        allow(Mail).to receive(:new).and_wrap_original do |method, &block|
          mail = method.call(&block)
          body = mail.html_part.body.encoded
          mail
        end

        described_class.send_alerts(listings)
        expect(body).to include('bike')
      end

      context 'when image URL is nil' do
        before { listings[0]['image_url'] = nil }

        it 'does not include img tag' do
          body = nil
          allow(Mail).to receive(:new).and_wrap_original do |method, &block|
            mail = method.call(&block)
            body = mail.html_part.body.encoded
            mail
          end

          described_class.send_alerts(listings)
          expect(body).not_to include('<img')
        end
      end

      context 'when price is missing' do
        before { listings[0]['price'] = nil }

        it 'displays N/A for price' do
          body = nil
          allow(Mail).to receive(:new).and_wrap_original do |method, &block|
            mail = method.call(&block)
            body = mail.html_part.body.encoded
            mail
          end

          described_class.send_alerts(listings)
          expect(body).to include('N/A')
        end
      end
    end

    context 'error handling' do
      it 'handles delivery errors gracefully' do
        allow(Mail).to receive(:new) do |&block|
          mail = double('Mail::Message')
          allow(mail).to receive(:deliver!).and_raise('SMTP Error')
          block.call(mail) if block
          mail
        end

        expect { described_class.send_alerts(listings) }.not_to raise_error
      end
    end
  end
end
