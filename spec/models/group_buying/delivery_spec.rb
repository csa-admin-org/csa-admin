require 'rails_helper'

describe GroupBuying::Delivery do
  it 'validates date after today' do
    delivery = described_class.new(date: 1.day.ago)
    expect(delivery).not_to have_valid(:date)
  end

  it 'validates orderable_until before date' do
    delivery = described_class.new(
      date: 3.day.ago,
      orderable_until: 2.day.ago)
    expect(delivery).not_to have_valid(:orderable_until)
  end
end
