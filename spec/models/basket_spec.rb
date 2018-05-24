require 'rails_helper'

describe Basket do
  it 'sets prices on creation' do
    basket = create(:basket,
      basket_size: create(:basket_size, price: 30),
      distribution: create(:distribution, price: 5))

    expect(basket.basket_price).to eq 30
    expect(basket.distribution_price).to eq 5
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
    membership = create(:membership, started_on: Current.fy_range.min + 6.months)
    delivery = create(:delivery, date: Current.fy_range.min + 1.month)

    basket = build(:basket, membership: membership, delivery: delivery)
    basket.validate

    expect(basket.errors[:delivery]).to be_present
  end

  it 'updates basket complement_prices when created' do
    basket = create(:basket)
    create(:basket_complement, id: 42, price: 3.2)

    expect {
      basket.update!(complement_ids: [42])
    }.to change(basket, :complements_price).from(0).to(3.2)
  end

  it 'removes basket complement_prices when destroyed' do
    basket = create(:basket)
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

  it 'sets basket_complement on creation when its match membership subscriptions (with season)' do
    Current.acp.update!(
      summer_month_range_min: 4,
      summer_month_range_max: 9)
    create(:basket_complement, id: 1, price: 3.2, name: 'Pain')
    create(:basket_complement, id: 2, price: 4.5, name: 'Oeuf')

    membership_1 = create(:membership, memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: nil, quantity: 1, seasons: ['summer']  },
        '1' => { basket_complement_id: 2, price: '4', quantity: 2 }
      })
    membership_2 = create(:membership, memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 2, price: '', quantity: 1, seasons: ['winter'] }
      })

    delivery = create(:delivery, date: '06-06-2018', basket_complement_ids: [1, 2])

    basket = create(:basket, membership: membership_1, delivery: delivery)
    expect(basket.complement_ids).to match_array [1, 2]
    expect(basket.complements_description).to eq 'Pain et 2 x Oeuf'
    expect(basket.complements_price).to eq 3.2 + 2 * 4

    basket = create(:basket, membership: membership_2, delivery: delivery)
    expect(basket.complement_ids).to match_array [2]
    expect(basket.complements_description).to be_nil
    expect(basket.complements_price).to be_zero
  end
end
