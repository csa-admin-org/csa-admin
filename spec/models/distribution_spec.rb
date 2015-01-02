require 'rails_helper'

describe Distribution do

  describe '.with_delivery_memberships' do
    subject { described_class.with_delivery_memberships(delivery) }

    let!(:distribution1) { create(:distribution) }
    let!(:distribution2) { create(:distribution) }
    let!(:distribution3) { create(:distribution) }
    let(:delivery) { Delivery.coming.first }
    before {
      create(:membership, distribution: distribution1)
      create(:membership, distribution: distribution1, started_on: delivery.date + 10.days)
      create(:membership, distribution: distribution2)
      create(:membership, distribution: distribution2)
    }

    it 'returns only used distributions' do
      expect(subject.size).to eq 2
    end

    it 'orders them by memberships count' do
      expect(subject.first).to eq distribution2
    end

    it 'includes only delivery memberships' do
      expect(subject.last.delivery_memberships.size).to eq 1
    end
  end

end
