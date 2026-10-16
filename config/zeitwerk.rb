# frozen_string_literal: true

require 'zeitwerk'

loader = Zeitwerk::Loader.new
loader.tag = 'marketplace_monitor'
loader.inflector.inflect('cli' => 'CLI', 'monitor' => 'MarketplaceMonitor')
loader.push_dir(File.join(__dir__, '..', 'lib'))
loader.push_dir(File.join(__dir__, '..', 'models'))
loader.push_dir(File.join(__dir__, '..', 'dtos'))
loader.setup
loader.eager_load
