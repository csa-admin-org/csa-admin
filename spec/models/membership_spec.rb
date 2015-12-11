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
      membership.update(
        started_on: Date.new(2015, 2),
        ended_on: Date.new(2015, 1)
      )
      expect(membership.errors[:started_on]).to be_present
      expect(membership.errors[:ended_on]).to be_present
    end

    it 'allows ended_on only in basket year' do
      membership.update(ended_on: Date.new(2000))
      expect(membership.errors[:ended_on]).to be_present
    end
  end

  describe '#will_be_changed_at=' do
    let!(:membership) { create(:membership) }
    let(:date) { Delivery.next_coming_date }

    context 'when not present' do
      it 'updates normaly' do
        expect { membership.update(will_be_changed_at: '') }.not_to change {
          Membership.count
        }
      end
    end

    context 'when present' do
      let(:new_membership) { Membership.last }

      specify do
        expect { membership.update(will_be_changed_at: date.to_s) }.to change {
          Membership.count
        }.by(1)
      end

      specify do
        expect {
          membership.update(annual_price: 100, will_be_changed_at: date.to_s)
        }.not_to change {
          membership.reload.started_on
        }
      end

      specify do
        expect {
          membership.update(annual_price: 100, will_be_changed_at: date.to_s)
        }.to change {
          membership.reload.ended_on
        }.to(date - 1.day)
      end

      specify do
        expect {
          membership.update(annual_price: 100, will_be_changed_at: date.to_s)
        }.not_to change {
          membership.reload.annual_price
        }
      end

      specify do
        membership.update(annual_price: 100, will_be_changed_at: date.to_s)
        expect(new_membership.started_on).to eq date
      end

      specify do
        ended_on = membership.ended_on
        membership.update(annual_price: 100, will_be_changed_at: date.to_s)
        expect(new_membership.ended_on).to eq ended_on
      end

      specify do
        membership.update(annual_price: 100, will_be_changed_at: date.to_s)
        expect(new_membership.annual_price).to eq 100
      end

      specify do
        membership.update(annual_price: 100, will_be_changed_at: date.to_s)
        expect(new_membership.member).to eq membership.member
      end

      specify do
        membership.update(annual_price: 100, will_be_changed_at: date.to_s)
        expect(new_membership.basket).to eq membership.basket
      end
    end

    context 'when present (past)' do
      it 'fails validation' do
        membership.update(will_be_changed_at: 1.days.ago.to_s)
        expect(membership.errors[:will_be_changed_at]).to be_present
      end
    end
  end

  describe '#renew' do
    let(:membership) { create(:membership) }
    let!(:basket) { create(:basket, :next_year, name: membership.basket.name) }
    let(:next_year) { Time.zone.today.next_year }
    before { membership.renew }
    subject { Membership.renew.first }

    specify { expect(subject.started_on).to eq next_year.beginning_of_year }
    specify { expect(subject.ended_on).to eq next_year.end_of_year }
    specify { expect(subject.member).to eq membership.member }
    specify { expect(subject.distribution).to eq membership.distribution }
    specify { expect(subject.basket).to eq basket }
    specify { expect(subject.note).to eq membership.note }
    specify { expect(subject.annual_price).to eq membership.annual_price }
    specify do
      expect(subject.annual_halfday_works).to eq membership.annual_halfday_works
    end
  end

  describe '#annual_halfday_works' do
    let(:membership) { create(:membership) }
    subject { membership.annual_halfday_works }

    it { is_expected.to eq 2 }

    context 'when member has a salary_basket' do
      let(:member) { create(:member, salary_basket: true) }
      let(:membership) { create(:membership, member: member) }

      it { is_expected.to eq 0 }
    end
  end

  describe '#total_basket_price' do
    let(:membership) { create(:membership) }
    subject { membership.total_basket_price }

    it { is_expected.to eq 30 }

    context 'when member has a salary_basket' do
      let(:member) { create(:member, salary_basket: true) }
      let(:membership) { create(:membership, member: member) }

      it { is_expected.to eq 0 }
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
      let(:membership) {
        create(:membership, basket: basket, annual_halfday_works: 1)
      }

      it { is_expected.to eq(2 * 60 / 40.0) }
    end

    context 'when annual_halfday_works is smaller than basket' do
      let(:basket) { create(:basket, annual_halfday_works: 2) }
      let(:membership) {
        create(:membership, basket: basket, annual_halfday_works: 4)
      }

      it { is_expected.to eq 0 }
    end
  end

  describe '#description' do
    let(:membership) { create(:membership, annual_halfday_works: 1) }
    subject { membership.description }
    before do
      membership.basket.update(annual_price: 925)
      membership.distribution.update(basket_price: 2)
    end

    it { is_expected.to include "#{membership.basket.name} (23.125), " }
    it { is_expected.to include "#{membership.distribution.name} (2.00), " }
    it { is_expected.to include 'sans ½ Journées de travail (1.50)' }
    it { is_expected.to include I18n.l membership.started_on, format: :number }
    it { is_expected.to include I18n.l membership.ended_on, format: :number }
    it { is_expected.to include "\n40 livraisons x (23.125 + 2.00 + 1.50)" }

    context 'free distribution basket_price' do
      before { membership.distribution.update(basket_price: 0) }

      it { is_expected.to include "#{membership.distribution.name}, " }
      it { is_expected.to include "\n40 livraisons x (23.125 + 1.50)" }
    end
  end
end
