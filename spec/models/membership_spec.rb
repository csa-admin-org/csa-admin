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
      expect(new_membership.errors[:member]).to include 'seulement un abonnement par an et par membre'
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

  it 'creates new baskets when started_on and ended_on changes' do
    membership = create(:membership)
    baskets = membership.baskets
    first_basket = baskets.first
    last_basket = baskets.last
    basket_size = last_basket.basket_size
    distribution = last_basket.distribution

    expect(membership.baskets_count).to eq(40)

    membership.update!(
      started_on: first_basket.delivery.date + 1.days,
      ended_on: last_basket.delivery.date - 1.days)
    expect(membership.baskets_count).to eq(38)

    new_basket_size = create(:basket_size)
    new_distribution = create(:distribution)
    membership.reload.baskets.first.update!(
      basket_size: new_basket_size,
      distribution: new_distribution)

    membership.update!(
      started_on: first_basket.delivery.date - 1.days,
      ended_on: last_basket.delivery.date + 1.days)

    expect(membership.reload.baskets_count).to eq(40)
    new_first_basket = membership.reload.baskets.first
    expect(new_first_basket.basket_size).to eq new_basket_size
    expect(new_first_basket.distribution).to eq new_distribution
    new_last_basket = membership.reload.baskets.last
    expect(new_last_basket.basket_size).to eq basket_size
    expect(new_last_basket.distribution).to eq distribution
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

    expect(membership.basket_sizes_price).to eq 40 * 23.125
    expect(membership.distributions_price).to eq 0
    expect(membership.halfday_works_price).to eq 0
    expect(membership.price).to eq membership.basket_sizes_price
  end

  specify 'with distribution prices' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      distribution_id: create(:distribution, price: 2).id)

    expect(membership.basket_sizes_price).to eq 40 * 23.125
    expect(membership.distributions_price).to eq 40 * 2
    expect(membership.halfday_works_price).to eq 0
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.distributions_price
  end

  specify 'with halfday_works_annual_price prices' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      distribution_id: create(:distribution, price: 2).id,
      halfday_works_annual_price: -200)

    expect(membership.basket_sizes_price).to eq 40 * 23.125
    expect(membership.distributions_price).to eq 40 * 2
    expect(membership.halfday_works_price).to eq(-200)
    expect(membership.price)
      .to eq(
        membership.basket_sizes_price +
        membership.distributions_price -
        200)
  end

  specify 'salary basket prices' do
    membership = create(:membership,
      member: create(:member, salary_basket: true))
    expect(membership.basket_sizes_price).to eq 0
    expect(membership.distributions_price).to eq 0
    expect(membership.halfday_works_price).to eq 0
    expect(membership.price).to eq 0
  end

  describe 'renew update' do
    it 'sets renew to true on creation when ended_on is end of year' do
      membership = create(:membership, ended_on: Date.current.end_of_year)
      expect(membership.renew).to eq true
    end

    it 'leaves renew to false on creation when ended_on is not end of year' do
      membership = create(:membership, ended_on: Date.current.end_of_year - 1.day)
      expect(membership.renew).to eq false
    end

    it 'sets renew to true when ended_on is changed to end of year' do
      membership = create(:membership, ended_on: Date.current.end_of_year - 1.day)
      membership.update!(ended_on: Date.current.end_of_year)
      expect(membership.renew).to eq true
    end

    it 'sets renew to false when ended_on is not changed to end of year' do
      membership = create(:membership, ended_on: Date.current.end_of_year)
      membership.update!(ended_on: Date.current.end_of_year - 1.day)
      expect(membership.renew).to eq false
    end

    it 'sets renew to false when changed manually' do
      membership = create(:membership, ended_on: Date.current.end_of_year)
      membership.update!(renew: false)
      expect(membership.renew).to eq false
    end
  end

  describe '#basket_complements_price_info' do
    it 'lists all complements with their different prices' do
      membership = create(:membership)
      create(:basket_complement, id: 1, price: 2.20)
      create(:basket_complement, id: 2, price: 3.30)

      membership.baskets.first.update!(complement_ids: [1, 2])
      membership.baskets.second.update!(complement_ids: [1, 2])
      membership.baskets.third.update!(complement_ids: [2])

      expect(membership.basket_complements_price_info).to eq '2 x 2.20 + 3 x 3.30'
    end
  end

  it 'adds basket_complement to coming baskets when subscription is added' do
    Timecop.freeze('2017-06-01') do
      create(:basket_complement, id: 1, price: 3.2)
      create(:basket_complement, id: 2, price: 4.5)
      membership = create(:membership, subscribed_basket_complement_ids: [])
      delivery_1 = create(:delivery, basket_complement_ids: [1], date: '2017-03-01')
      delivery_2 = create(:delivery, basket_complement_ids: [2], date: '2017-07-01')
      delivery_3 = create(:delivery, basket_complement_ids: [1, 2], date: '2017-08-01')
      delivery_4 = create(:delivery, basket_complement_ids: [1], date: '2017-08-02')

      basket1 = create(:basket, membership: membership, delivery: delivery_1)
      basket2 = create(:basket, membership: membership, delivery: delivery_2)
      basket3 = create(:basket, membership: membership, delivery: delivery_3)
      basket4 = create(:basket, membership: membership, delivery: delivery_4)
      basket4.update!(complement_ids: [1, 2])

      membership.update!(subscribed_basket_complement_ids: [1])

      basket1.reload
      expect(basket1.complement_ids).to be_empty
      expect(basket1.complements_price).to be_zero

      basket2.reload
      expect(basket2.complement_ids).to be_empty
      expect(basket2.complements_price).to be_zero

      basket3.reload
      expect(basket3.complement_ids).to match_array [1]
      expect(basket3.complements_price).to eq 3.2

      basket4.reload
      expect(basket4.complement_ids).to match_array [1, 2]
      expect(basket4.complements_price).to eq 3.2 + 4.5

      expect(membership.basket_complements_price).to eq 3.2 + 3.2 + 4.5
    end
  end

  it 'removes basket_complement to coming baskets when subscription is removed' do
    Timecop.freeze('2017-06-01') do
      create(:basket_complement, id: 1, price: 3.2)
      create(:basket_complement, id: 2, price: 4.5)

      membership = create(:membership, subscribed_basket_complement_ids: [1, 2])
      delivery_1 = create(:delivery, basket_complement_ids: [1], date: '2017-03-01')
      delivery_2 = create(:delivery, basket_complement_ids: [1], date: '2017-07-01')
      delivery_3 = create(:delivery, basket_complement_ids: [1, 2], date: '2017-08-01')
      delivery_4 = create(:delivery, basket_complement_ids: [2], date: '2017-08-02')

      basket1 = create(:basket, membership: membership, delivery: delivery_1)
      basket2 = create(:basket, membership: membership, delivery: delivery_2)
      basket3 = create(:basket, membership: membership, delivery: delivery_3)
      basket4 = create(:basket, membership: membership, delivery: delivery_4)
      basket4.update!(complement_ids: [1, 2])

      membership.reload # reset subscribed_basket_complements
      membership.update!(subscribed_basket_complement_ids: [2])

      basket1.reload
      expect(basket1.complement_ids).to match_array [1]
      expect(basket1.complements_price).to eq 3.2

      basket2.reload
      expect(basket2.complement_ids).to be_empty
      expect(basket2.complements_price).to be_zero

      basket3.reload
      expect(basket3.complement_ids).to match_array [2]
      expect(basket3.complements_price).to eq 4.5

      basket4.reload
      expect(basket4.complement_ids).to match_array [1, 2]
      expect(basket4.complements_price).to eq 3.2 + 4.5

      expect(membership.basket_complements_price).to eq 3.2 + 4.5 + 3.2 + 4.5
    end
  end
end
