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

  it 'compacts depot_ids when set' do
    delivery = described_class.new(depot_ids: ['', nil, '1', 4])

    expect(delivery.depot_ids).to eq([1, 4])
  end

  describe '#can_access?' do
    specify 'allowed when no depot_ids set' do
      delivery = described_class.new(depot_ids: [])
      expect(delivery.can_access?('foo')).to eq true
    end

    specify 'allowed when next basket depot is in the list', freeze: '2023-01-01' do
      membership = create(:membership)
      delivery = described_class.new(depot_ids: [membership.next_basket.depot_id])

      expect(delivery.can_access?(membership.member)).to be_truthy
    end

    specify 'not allowed when next basket depot is not in the list', freeze: '2023-01-01' do
      membership = create(:membership)
      delivery = described_class.new(depot_ids: [membership.depot_id + 1])

      expect(delivery.can_access?(membership.member)).to be_falsey
    end

    specify 'not allowed when user has no next basket' do
      member = create(:member)
      delivery = described_class.new(depot_ids: [1])

      expect(delivery.can_access?(member)).to be_falsey
    end
  end
end
