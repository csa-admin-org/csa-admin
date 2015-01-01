require 'rails_helper'

describe Billing do
  describe '.all' do
    subject { described_class.all.first }
    let(:membership) { member.current_membership }

    context 'when active' do
      let!(:member) { create(:member, :active) }

      specify { expect(subject.member_name).to eq member.name }
      specify { expect(subject.price).to eq membership.deliveries_count * membership.basket_price }
    end

    context 'when active (and billing_support)' do
      let!(:member) { create(:member, :active) }
      before { create(:membership, billing_member: member)}

      specify { expect(subject.member_name).to eq member.name }
      specify { expect(subject.price).to eq 2 * membership.deliveries_count * membership.basket_price }
    end

    context 'when trial' do
      let!(:member) { create(:member, :trial) }

      specify { expect(subject).to be_nil }
    end

    context 'when support' do
      let!(:member) { create(:member, :support) }

      specify { expect(subject.member_name).to eq member.name }
      specify { expect(subject.price).to eq 30 }
      specify { expect(subject.details).to eq 'Soutien: 30.00 sFr.' }
    end
  end
end
