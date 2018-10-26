require 'rails_helper'

describe Delivery do
  it_behaves_like 'bulk_dates_insert'

  it 'returns delivery season' do
    Current.acp.update!(
      summer_month_range_min: 4,
      summer_month_range_max: 9)
    delivery = create(:delivery, date: '12-10-2017')

    expect(delivery.season).to eq 'winter'
  end

  it 'adds basket_complement on subscribed baskets' do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    membership_1 = create(:membership, subscribed_basket_complement_ids: [1, 2])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [2])
    membership_3 = create(:membership, subscribed_basket_complement_ids: [1])

    delivery = create(:delivery)

    basket1 = create(:basket, membership: membership_1, delivery: delivery)
    basket2 = create(:basket, membership: membership_2, delivery: delivery)
    basket3 = create(:basket, membership: membership_3, delivery: delivery)
    basket3.update!(complement_ids: [1, 2])

    delivery.update!(basket_complement_ids: [1, 2])

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


  it 'adds basket_complement on subscribed baskets (with season)' do
    Current.acp.update!(
      summer_month_range_min: 4,
      summer_month_range_max: 9)

    create(:basket_complement, id: 1, price: 4.5, name: 'Oeuf')
    membership = create(:membership, memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: nil, quantity: 1, seasons: ['summer']  },
      })

    delivery1 = create(:delivery, date: '06-06-2018')
    delivery2 = create(:delivery, date: '06-12-2018')

    basket1 = create(:basket, membership: membership, delivery: delivery1)
    basket2 = create(:basket, membership: membership, delivery: delivery2)

    delivery1.update!(basket_complement_ids: [1])

    basket1.reload
    expect(basket1.complement_ids).to match_array [1]
    expect(basket1.complements_description).to eq 'Oeuf'
    expect(basket1.complements_price).to eq 4.5

    delivery2.update!(basket_complement_ids: [1])

    basket2.reload
    expect(basket2.complement_ids).to match_array [1]
    expect(basket2.complements_description).to be_nil
    expect(basket2.complements_price).to be_zero
  end

  it 'removes basket_complement on subscribed baskets' do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    membership_1 = create(:membership, subscribed_basket_complement_ids: [1, 2])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [2])
    membership_3 = create(:membership, subscribed_basket_complement_ids: [1])

    delivery = create(:delivery, basket_complement_ids: [1, 2])

    basket1 = create(:basket, membership: membership_1, delivery: delivery)
    basket2 = create(:basket, membership: membership_2, delivery: delivery)
    basket3 = create(:basket, membership: membership_3, delivery: delivery)
    basket3.update!(complement_ids: [1, 2])

    delivery.update!(basket_complement_ids: [1])

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

  it 'updates all fiscal year delivery numbers' do
    first = create(:delivery, date: '2018-02-01')
    last = create(:delivery, date: '2018-11-01')

    expect(first.number).to eq 1
    expect(last.number).to eq 2

    delivery = create(:delivery, date: '2018-06-01')

    expect(first.reload.number).to eq 1
    expect(delivery.reload.number).to eq 2
    expect(last.reload.number).to eq 3

    delivery.update!(date: '2018-01-01')

    expect(delivery.reload.number).to eq 1
    expect(first.reload.number).to eq 2
    expect(last.reload.number).to eq 3
  end
end
