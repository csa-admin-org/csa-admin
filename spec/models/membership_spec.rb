require 'rails_helper'

describe Membership do
  it 'sets annual_halfday_works default' do
    expect(Membership.new.annual_halfday_works)
      .to eq HalfdayParticipation::MEMBER_PER_YEAR
  end

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

    it 'allows started_on to be only smaller than ended_on' do
      membership.update(
        started_on: Date.new(2015, 2),
        ended_on: Date.new(2015, 1)
      )
      expect(membership.errors[:started_on]).to be_present
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
      around { |ex| Timecop.travel(Time.zone.now.beginning_of_year) { ex.run } }

      specify do
        expect { membership.update(will_be_changed_at: date.to_s) }.to change {
          Membership.count
        }.by(1)
      end

      specify do
        expect {
          membership.update(
            halfday_works_annual_price: -100,
            will_be_changed_at: date.to_s
          )
        }.not_to change {
          membership.reload.started_on
        }
      end

      specify do
        expect {
          membership.update(
            halfday_works_annual_price: -100,
            will_be_changed_at: date.to_s
          )
        }.to change {
          membership.reload.ended_on
        }.to(date - 1.day)
      end

      specify do
        expect {
          membership.update(
            halfday_works_annual_price: -100,
            will_be_changed_at: date.to_s
          )
        }.not_to change {
          membership.reload.halfday_works_annual_price
        }
      end

      specify do
        membership.update(
          halfday_works_annual_price: -100,
          will_be_changed_at: date.to_s
        )
        expect(new_membership.started_on).to eq date
      end

      specify do
        ended_on = membership.ended_on
        membership.update(
          halfday_works_annual_price: -100,
          will_be_changed_at: date.to_s
        )
        expect(new_membership.ended_on).to eq ended_on
      end

      specify do
        membership.update(
          halfday_works_annual_price: -100,
          will_be_changed_at: date.to_s
        )
        expect(new_membership.halfday_works_annual_price).to eq(-100)
      end

      specify do
        membership.update(
          halfday_works_annual_price: -100,
          will_be_changed_at: date.to_s
        )
        expect(new_membership.member).to eq membership.member
      end

      specify do
        membership.update(
          halfday_works_annual_price: -100,
          will_be_changed_at: date.to_s
        )
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

  specify '#renew' do
    membership = create(:membership)
    next_year = Time.zone.today.next_year
    membership.renew
    new_membership = Membership.renew.first

    expect(new_membership.started_on).to eq next_year.beginning_of_year
    expect(new_membership.ended_on).to eq next_year.end_of_year
    expect(new_membership.member).to eq membership.member
    expect(new_membership.distribution).to eq membership.distribution
    expect(new_membership.basket).to eq membership.basket
    expect(new_membership.note).to eq membership.note
    expect(new_membership.halfday_works_annual_price)
      .to eq membership.halfday_works_annual_price
    expect(new_membership.annual_halfday_works)
      .to eq membership.annual_halfday_works
  end

  specify 'standard prices' do
    membership = create(:membership,
      basket: create(:basket, annual_price: 40 * 23.125)
    )

    expect(membership.basket_total_price).to eq 40 * 23.125
    expect(membership.distribution_total_price).to eq 0
    expect(membership.halfday_works_total_price).to eq 0
    expect(membership.price).to eq membership.basket_total_price
  end

  specify 'with distribution prices' do
    membership = create(:membership,
      basket: create(:basket, annual_price: 40 * 23.125),
      distribution: create(:distribution, basket_price: 2)
    )

    expect(membership.basket_total_price).to eq 40 * 23.125
    expect(membership.distribution_total_price).to eq 40 * 2
    expect(membership.halfday_works_total_price).to eq 0
    expect(membership.price)
      .to eq membership.basket_total_price + membership.distribution_total_price
  end

  specify 'with halfday_works_annual_price prices' do
    membership = create(:membership,
      basket: create(:basket, annual_price: 40 * 23.125),
      distribution: create(:distribution, basket_price: 2),
      halfday_works_annual_price: -200
    )

    expect(membership.basket_total_price).to eq 40 * 23.125
    expect(membership.distribution_total_price).to eq 40 * 2
    expect(membership.halfday_works_total_price).to eq(-200)
    expect(membership.price)
      .to eq(
        membership.basket_total_price +
        membership.distribution_total_price -
        200
      )
  end

  specify 'salary basket prices' do
    membership = create(:membership,
      member: create(:member, salary_basket: true)
    )
    expect(membership.basket_total_price).to eq 0
    expect(membership.distribution_total_price).to eq 0
    expect(membership.halfday_works_total_price).to eq 0
    expect(membership.price).to eq 0
  end
end
