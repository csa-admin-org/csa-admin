require 'rails_helper'

describe Membership do
  it 'sets annual_halfday_works default' do
    basket_size = create(:basket_size, annual_halfday_works: 3)
    membership = create(:membership, basket_size_id: basket_size.id)

    expect(membership.annual_halfday_works).to eq 3
  end

  describe 'validations' do
    let(:membership) { create(:membership) }

    it 'allows only one current memberships per member' do
      new_membership = Membership.new(membership.attributes.except('id'))
      new_membership.validate
      expect(new_membership.errors[:base]).to include 'seulement un abonnement par an et par membre'
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

    it 'allows started_on to be only on the same year than ended_on' do
      membership.update(
        started_on: Date.new(2014, 1),
        ended_on: Date.new(2015, 12)
      )
      expect(membership.errors[:started_on]).to be_present
      expect(membership.errors[:ended_on]).to be_present
    end
  end

  it 'creates baskets on creation' do
    basket_size = create(:basket_size)
    distribution = create(:distribution)

    membership = create(:membership,
      basket_size_id: basket_size.id,
      distribution_id: distribution.id)

    expect(membership.baskets.count).to eq(40)
    expect(membership.baskets_count).to eq(40)
    expect(membership.baskets.pluck(:basket_size_id).uniq).to eq [basket_size.id]
    expect(membership.baskets.pluck(:distribution_id).uniq).to eq [distribution.id]
  end

  it 'deletes baskets when started_on and ended_on changes' do
    membership = create(:membership)
    baskets = membership.baskets
    first_basket = baskets.first
    last_basket = baskets.last

    expect(membership.baskets_count).to eq(40)

    membership.update!(
      started_on: first_basket.delivery.date + 1.days,
      ended_on: last_basket.delivery.date - 1.days)

    expect(membership.baskets_count).to eq(38)
    expect { first_basket.reload }.to raise_error ActiveRecord::RecordNotFound
    expect { last_basket.reload }.to raise_error ActiveRecord::RecordNotFound
  end

  it 'updates future baskets/distribution when present' do
    basket_size = create(:basket_size)
    distribution = create(:distribution)
    membership = create(:membership,
      basket_size_id: basket_size.id,
      distribution_id: distribution.id)
    new_basket_size = create(:basket_size)
    new_distribution = create(:distribution)

    expect(membership.baskets_count).to eq(40)
    beginning_of_year = Time.current.beginning_of_year
    middle_of_year = Time.current.beginning_of_year + 6.months
    end_of_year = Time.current.end_of_year

    Timecop.travel(middle_of_year) do
      membership.update!(
        basket_size_id: new_basket_size.id,
        distribution_id: new_distribution.id)
    end

    expect(membership.baskets_count).to eq(40)
    expect(membership.baskets.between(beginning_of_year..middle_of_year).pluck(:basket_size_id).uniq)
      .to eq [basket_size.id]
    expect(membership.baskets.between(middle_of_year..end_of_year).pluck(:basket_size_id).uniq)
      .to eq [new_basket_size.id]
    expect(membership.baskets.between(beginning_of_year..middle_of_year).pluck(:distribution_id).uniq)
      .to eq [distribution.id]
    expect(membership.baskets.between(middle_of_year..end_of_year).pluck(:distribution_id).uniq)
      .to eq [new_distribution.id]
  end

  specify 'standard prices' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id)

    expect(membership.basket_total_price).to eq 40 * 23.125
    expect(membership.distribution_total_price).to eq 0
    expect(membership.halfday_works_total_price).to eq 0
    expect(membership.price).to eq membership.basket_total_price
  end

  specify 'with distribution prices' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      distribution_id: create(:distribution, price: 2).id)

    expect(membership.basket_total_price).to eq 40 * 23.125
    expect(membership.distribution_total_price).to eq 40 * 2
    expect(membership.halfday_works_total_price).to eq 0
    expect(membership.price)
      .to eq membership.basket_total_price + membership.distribution_total_price
  end

  specify 'with halfday_works_annual_price prices' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      distribution_id: create(:distribution, price: 2).id,
      halfday_works_annual_price: -200)

    expect(membership.basket_total_price).to eq 40 * 23.125
    expect(membership.distribution_total_price).to eq 40 * 2
    expect(membership.halfday_works_total_price).to eq(-200)
    expect(membership.price)
      .to eq(
        membership.basket_total_price +
        membership.distribution_total_price -
        200)
  end

  specify 'salary basket prices' do
    membership = create(:membership,
      member: create(:member, salary_basket: true))
    expect(membership.basket_total_price).to eq 0
    expect(membership.distribution_total_price).to eq 0
    expect(membership.halfday_works_total_price).to eq 0
    expect(membership.price).to eq 0
  end
end
