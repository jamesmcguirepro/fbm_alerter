# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PriceFormatter do
  it 'returns N/A for nil' do
    expect(described_class.format(nil)).to eq('N/A')
  end

  it 'adds thousands separators' do
    expect(described_class.format(1234.5)).to eq('$1,234.50')
    expect(described_class.format(1_234_567)).to eq('$1,234,567')
  end

  it 'omits cents for whole-dollar amounts' do
    expect(described_class.format(250.0)).to eq('$250')
  end
end
