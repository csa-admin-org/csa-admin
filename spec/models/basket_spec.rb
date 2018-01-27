require 'rails_helper'

describe Basket do
  it 'sets prices on creation' do
    basket = create(:basket,
      basket_size: create(:basket_size, price: 30),
      distribution: create(:distribution, price: 5))

    expect(basket.basket_price).to eq 30
    expect(basket.distribution_price).to eq 5
  end

  it 'updates price when other prices change' do
    basket = create(:basket,
      basket_size: create(:basket_size, price: 30),
      distribution: create(:distribution, price: 5))

    basket.update!(basket_size_id: create(:basket_size, price: 35).id)
    expect(basket.basket_price).to eq(35)

    basket.update!(distribution: create(:distribution, price: 2))
    expect(basket.distribution_price).to eq(2)
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

  it 'sets basket_complement on creation when its match membership and delivery ones' do
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
end
