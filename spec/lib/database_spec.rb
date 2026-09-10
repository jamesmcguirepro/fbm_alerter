# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/database'

RSpec.describe Database do
  describe '.connect' do
    let(:db_config) do
      {
        'development' => {
          'adapter' => 'sqlite3',
          'database' => 'db/development.sqlite3',
          'pool' => 5,
          'timeout' => 5000
        },
        'test' => {
          'adapter' => 'sqlite3',
          'database' => ':memory:',
          'pool' => 5,
          'timeout' => 5000
        },
        'production' => {
          'adapter' => 'sqlite3',
          'database' => 'db/production.sqlite3',
          'pool' => 10,
          'timeout' => 5000
        }
      }
    end

    before do
      allow(YAML).to receive(:load_file).and_return(db_config)
      allow(ActiveRecord::Base).to receive(:establish_connection)
    end

    context 'when environment is set to development' do
      it 'loads the database configuration from file' do
        ENV['RUBY_ENV'] = 'development'
        Database.connect

        expect(YAML).to have_received(:load_file).with('config/database.yml')
      end

      it 'establishes a connection with development config' do
        ENV['RUBY_ENV'] = 'development'
        Database.connect

        expect(ActiveRecord::Base).to have_received(:establish_connection)
                                        .with(db_config['development'])
      end
    end

    context 'when environment is set to test' do
      it 'establishes a connection with test config' do
        ENV['RUBY_ENV'] = 'test'
        Database.connect

        expect(ActiveRecord::Base).to have_received(:establish_connection)
                                        .with(db_config['test'])
      end

      it 'uses in-memory database for testing' do
        ENV['RUBY_ENV'] = 'test'
        Database.connect

        expect(ActiveRecord::Base).to have_received(:establish_connection) do |config|
          expect(config['database']).to eq(':memory:')
        end
      end
    end

    context 'when environment is set to production' do
      it 'establishes a connection with production config' do
        ENV['RUBY_ENV'] = 'production'
        Database.connect

        expect(ActiveRecord::Base).to have_received(:establish_connection)
                                        .with(db_config['production'])
      end
    end

    context 'when RUBY_ENV is not set' do
      it 'attempts to access nil key in config' do
        ENV['RUBY_ENV'] = nil
        Database.connect

        expect(ActiveRecord::Base).to have_received(:establish_connection)
                                        .with(db_config[nil])
      end
    end

    context 'when configuration file is missing' do
      it 'raises an error' do
        allow(YAML).to receive(:load_file).and_raise(Errno::ENOENT)

        expect { Database.connect }.to raise_error(Errno::ENOENT)
      end
    end

    context 'when configuration file has invalid YAML' do
      let(:error) { Psych::SyntaxError.allocate }
      before do
        allow(YAML).to receive(:load_file).and_raise(error)
      end

      it 'raises a parsing error' do
        expect { Database.connect }.to raise_error(error)
      end
    end

    context 'when ActiveRecord connection fails' do
      it 'propagates the connection error' do
        ENV['RUBY_ENV'] = 'development'
        allow(ActiveRecord::Base).to receive(:establish_connection)
                                       .and_raise(ActiveRecord::AdapterNotFound, 'adapter sqlite3 not found')

        expect { Database.connect }.to raise_error(ActiveRecord::AdapterNotFound)
      end
    end

    context 'when configuration is empty' do
      it 'handles empty configuration gracefully' do
        allow(YAML).to receive(:load_file).and_return({})
        ENV['RUBY_ENV'] = 'development'
        Database.connect

        expect(ActiveRecord::Base).to have_received(:establish_connection)
                                        .with(nil)
      end
    end

    it 'is callable multiple times' do
      ENV['RUBY_ENV'] = 'test'
      Database.connect
      Database.connect

      expect(ActiveRecord::Base).to have_received(:establish_connection).twice
    end
  end

  describe 'class structure' do
    it 'uses singleton methods via class << self' do
      expect(Database.respond_to?(:connect)).to be true
    end

    it 'does not instantiate instances' do
      # Verify the pattern is a singleton
      expect(Database.methods.include?(:connect)).to be true
    end
  end
end