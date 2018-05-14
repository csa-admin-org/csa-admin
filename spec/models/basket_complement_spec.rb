require 'rails_helper'

describe BasketComplement do
  it 'adds basket_complement on subscribed baskets' do
    basket_complement1 = create(:basket_complement, id: 1, price: 3.2)
    basket_complement2 = create(:basket_complement, id: 2, price: 4.5)

    membership_1 = create(:membership, subscribed_basket_complement_ids: [1, 2])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [2])
    membership_3 = create(:membership, subscribed_basket_complement_ids: [1])

    delivery = create(:delivery)

    basket1 = create(:basket, membership: membership_1, delivery: delivery)
    basket2 = create(:basket, membership: membership_2, delivery: delivery)
    basket3 = create(:basket, membership: membership_3, delivery: delivery)
    basket3.update!(complement_ids: [1, 2])

    basket_complement1.update!(delivery_ids: [delivery.id])
    basket_complement2.update!(delivery_ids: [delivery.id])

    basket1.reload
    expect(basket1.complement_ids).to match_array [1, 2]
    expect(basket1.complements_price).to eq 3.2 + 4.5

    basket2.reload
    expect(basket2.complement_ids).to match_array [2]
    expect(basket2.complements_price).to eq 4.5

    basket3.reload
    expect(basket3.complement_ids).to match_array [1, 2]
    expect(basket3.complements_price).to eq 3.2 + 4.5
  end

  it 'removes basket_complement on subscribed baskets' do
    basket_complement1 = create(:basket_complement, id: 1, price: 3.2)
    basket_complement2 = create(:basket_complement, id: 2, price: 4.5)

    membership_1 = create(:membership, subscribed_basket_complement_ids: [1, 2])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [2])
    membership_3 = create(:membership, subscribed_basket_complement_ids: [1])

    delivery = create(:delivery, basket_complement_ids: [1, 2])

    basket1 = create(:basket, membership: membership_1, delivery: delivery)
    basket2 = create(:basket, membership: membership_2, delivery: delivery)
    basket3 = create(:basket, membership: membership_3, delivery: delivery)
    basket3.update!(complement_ids: [1, 2])

    basket_complement2.reload.update!(delivery_ids: [])

    basket1.reload
    expect(basket1.complement_ids).to match_array [1]
    expect(basket1.complements_price).to eq 3.2

    basket2.reload
    expect(basket2.complement_ids).to be_empty
    expect(basket2.complements_price).to be_zero

    basket3.reload
    expect(basket3.complement_ids).to match_array [1, 2]
    expect(basket3.complements_price).to eq 3.2 + 4.5
  end
end
