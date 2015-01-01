require 'rails_helper'

describe Membership do
  describe 'validations' do
    let(:membership) { create(:membership) }

    it 'allows only one current memberships per member' do
      new_membership = Membership.new(membership.attributes.except('id'))
      new_membership.valid?
      expect(new_membership.errors[:started_on]).to be_present
      expect(new_membership.errors[:ended_on]).to be_present
    end

    it 'allows valid attributes' do
      new_membership = Membership.new(membership.attributes.except('id'))
      new_membership.member = create(:member)
      expect(new_membership.errors).to be_empty
    end

    it 'allows started_on only in basket year' do
      membership.update(started_on: Date.new(2000))
      expect(membership.errors[:started_on]).to be_present
    end

    it 'allows started_on to be only smaller than ended_on' do
      membership.update(started_on: Date.new(2015, 2), ended_on: Date.new(2015, 1))
      expect(membership.errors[:started_on]).to be_present
      expect(membership.errors[:ended_on]).to be_present
    end

    it 'allows ended_on only in basket year' do
      membership.update(ended_on: Date.new(2000))
      expect(membership.errors[:ended_on]).to be_present
    end
  end

  describe '#billing_member' do
    subject { membership.billing_member }

    context 'when explicitly set' do
      let(:member) { create(:member) }
      let(:membership) { create(:membership, billing_member: member) }

      it { is_expected.to eq member }
    end

    context 'when not set' do
      let(:membership) { create(:membership) }

      it { is_expected.to eq membership.member }
    end
  end

  describe '#halfday_works_basket_price' do
    subject { membership.halfday_works_basket_price }

    context 'when annual_halfday_works is nil' do
      let(:membership) { create(:membership, annual_halfday_works: nil) }

      it { is_expected.to eq 0 }
    end

    context 'when annual_halfday_works is smaller than basket' do
      let(:basket) { create(:basket, annual_halfday_works: 3) }
      let(:membership) { create(:membership, basket: basket, annual_halfday_works: 1) }

      it { is_expected.to eq(2 * 60 / 40.0) }
    end

    context 'when annual_halfday_works is smaller than basket' do
      let(:basket) { create(:basket, annual_halfday_works: 2) }
      let(:membership) { create(:membership, basket: basket, annual_halfday_works: 4) }

      it { is_expected.to eq 0 }
    end
  end
end
