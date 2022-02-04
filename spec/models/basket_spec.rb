require 'rails_helper'

describe Basket do
  it 'sets prices before validation' do
    basket = build(:basket,
      basket_size: create(:basket_size, price: 30),
      depot: create(:depot, price: 5))
    basket.validate

    expect(basket.basket_price).to eq 30
    expect(basket.depot_price).to eq 5
  end

  it 'validates basket_complement_id uniqueness' do
    create(:basket_complement, id: 1)

    basket = build(:basket,
      baskets_basket_complements_attributes: {
        '0' => { basket_complement_id: 1 },
        '1' => { basket_complement_id: 1 }
      })
    basket.validate
    bbc = basket.baskets_basket_complements.last

    expect(bbc.errors[:basket_complement_id]).to be_present
  end

  it 'validates delivery is in membership date range', freeze: '2022-01-01' do
    delivery = create(:delivery, date: '2022-01-01')
    create(:delivery, date: '2022-03-01')
    membership = build(:membership, started_on: '2022-02-01')

    basket = build(:basket, membership: membership, delivery: delivery)
    basket.validate

    expect(basket.errors[:delivery]).to be_present
  end

  it 'validates delivery is in membership date range', freeze: '2022-01-01' do
    delivery1 = create(:delivery, date: '2022-01-03') # Monday
    delivery2 = create(:delivery, date: '2022-01-04')
    depot = create(:depot, deliveries_cycles: [
      create(:deliveries_cycle, wdays: [1])
    ])

    basket = build(:basket, depot: depot, delivery: delivery2)
    basket.validate

    expect(basket.errors[:depot]).to be_present
  end

  it 'updates basket complement_prices when created' do
    basket = create(:membership).baskets.first
    create(:basket_complement, id: 42, price: 3.2)

    expect {
      basket.update!(complement_ids: [42])
    }.to change(basket, :complements_price).from(0).to(3.2)
  end

  it 'removes basket complement_prices when destroyed' do
    basket = create(:membership).baskets.first
    create(:basket_complement, id: 42, price: 3.2)
    create(:basket_complement, id: 47, price: 4.5)
    basket.update!(complement_ids: [47, 42])

    expect {
      basket.update!(complement_ids: [47])
    }.to change(basket, :complements_price).from(3.2 + 4.5).to(4.5)
  end

  it 'sets basket_complement on creation when its match membership subscriptions' do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    create(:delivery)
    membership_1 = create(:membership, subscribed_basket_complement_ids: [1, 2])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [2])
    delivery = create(:delivery, basket_complement_ids: [1, 2])

    basket1 = delivery.baskets.find_by(membership: membership_1)
    expect(basket1.complement_ids).to match_array [1, 2]
    expect(basket1.complements_price).to eq 3.2 + 4.5

    basket2 = delivery.baskets.find_by(membership: membership_2)
    expect(basket2.complement_ids).to match_array [2]
    expect(basket2.complements_price).to eq 4.5
  end
end
