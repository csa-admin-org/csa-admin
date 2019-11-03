require 'rails_helper'

describe GroupBuying::Producer do
  it 'validates name presence' do
    producer = described_class.new(name: '')
    expect(producer).not_to have_valid(:name)
  end
end
