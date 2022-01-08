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

  it 'validates delivery is in membership date range' do
    delivery = create(:delivery, date: Current.fy_range.min + 1.month)
    create(:delivery, date: Current.fy_range.min + 7.month)
    membership = create(:membership, started_on: Current.fy_range.min + 6.months)

    basket = build(:basket, membership: membership, delivery: delivery)
    basket.validate

    expect(basket.errors[:delivery]).to be_present
  end

  it 'validates delivery is in membership date range' do
    delivery1 = create(:delivery, date: Date.today)
    delivery2 = create(:delivery, date: Date.yesterday)
    depot = create(:depot, delivery_ids: [delivery1.id])

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

    basket = create(:basket, membership: membership_1, delivery: delivery)
    expect(basket.complement_ids).to match_array [1, 2]
    expect(basket.complements_price).to eq 3.2 + 4.5

    basket = create(:basket, membership: membership_2, delivery: delivery)
    expect(basket.complement_ids).to match_array [2]
    expect(basket.complements_price).to eq 4.5
  end
end
