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

  it 'validates bulk inserts with depots' do
    depot = create(:depot, id: 2)
    create(:membership, depot: depot)

    delivery = Delivery.create(
      bulk_dates_starts_on: Date.today,
      bulk_dates_wdays: [1],
      date: Date.today,
      depot_ids: [2])

    expect(delivery).not_to have_valid(:bulk_dates_starts_on)
    expect(delivery).not_to have_valid(:bulk_dates_wdays)
  end

  it 'bulk inserts with depots and basket_complements' do
    create(:basket_complement, id: 1)
    create(:depot, id: 2, deliveries_count: 0)

    Delivery.create(
      bulk_dates_starts_on: Date.parse('2018-11-05'),
      bulk_dates_ends_on: Date.parse('2018-11-11') + 1.month,
      bulk_dates_weeks_frequency: 2,
      bulk_dates_wdays: [1],
      depot_ids: [2],
      basket_complement_ids: [1])

    expect(Delivery.count).to eq 3
    expect(Delivery.all.map(&:basket_complement_ids)).to eq [[1], [1], [1]]
    expect(Delivery.all.map(&:depot_ids)).to eq [[2], [2], [2]]
  end

  it 'adds basket_complement on subscribed baskets' do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    create(:delivery)
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

  it 'removes basket_complement on subscribed baskets' do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    create(:delivery)
    membership_1 = create(:membership, subscribed_basket_complement_ids: [1, 2])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [2])
    membership_3 = create(:membership, subscribed_basket_complement_ids: [1])

    delivery = create(:delivery, basket_complement_ids: [1, 2])

    basket1 = create(:basket, membership: membership_1, delivery: delivery)
    basket2 = create(:basket, membership: membership_2, delivery: delivery)
    basket3 = create(:basket, membership: membership_3, delivery: delivery)
    basket3.update!(complement_ids: [1, 2])

    expect { delivery.update!(basket_complement_ids: [1]) }
      .to change { membership_1.reload.price }.by(-4.5)
      .and change { membership_2.reload.price }.by(-4.5)

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

  it 'adds baskets when a depot is added' do
    depot = create(:depot, deliveries_count: 3)
    delivery1 = depot.deliveries[0]
    delivery2 = depot.deliveries[1]
    delivery3 = depot.deliveries[2]
    depot.update!(delivery_ids: [delivery1.id, delivery3.id])

    membership1 = create(:membership, depot: depot)
    membership2 = create(:membership, depot: depot)

    expect(membership1.deliveries).to eq [delivery1, delivery3]
    expect(membership2.deliveries).to eq membership1.deliveries

    expect {
      delivery2.update!(depot_ids: [depot.id])
    }.to change { Basket.count }.by(2)

    expect(membership1.reload.deliveries).to eq [delivery1, delivery2, delivery3]
    expect(membership2.reload.deliveries).to eq membership1.deliveries

    expect(membership1.baskets[1].delivery).to eq delivery2
    expect(membership2.baskets[1].delivery).to eq delivery2
  end

  it 'adds baskets when a depot is added with membership already with a basket to another depot' do
    depot1 = create(:depot, deliveries_count: 3)
    delivery1 = depot1.deliveries[0]
    delivery2 = depot1.deliveries[1]
    delivery3 = depot1.deliveries[2]
    depot1.update!(delivery_ids: [delivery1.id, delivery3.id])
    depot2 = create(:depot, delivery_ids: [delivery2.id])
    membership = create(:membership, depot: depot1)
    create(:basket, membership: membership, depot: depot2, delivery: delivery2)

    expect(membership.deliveries).to eq [delivery1, delivery2, delivery3]
    expect(membership.baskets.map(&:depot)).to eq [depot1, depot2, depot1]

    expect {
      delivery2.update!(depot_ids: [depot1.id, depot2.id])
    }.to change { Basket.count }.by(0)

    expect(membership.reload.deliveries).to eq [delivery1, delivery2, delivery3]
    expect(membership.reload.baskets.map(&:depot)).to eq [depot1, depot2, depot1]
  end

  it 'updated membership price when destroy' do
    basket_size = create(:basket_size, price: 42)
    membership = create(:membership, basket_size: basket_size)
    delivery = membership.deliveries.last

    expect { delivery.destroy! }
      .to change { membership.baskets.with_deleted.count }.by(-1)
      .and change { membership.reload.price }.by(-42)
  end

  it 'removes baskets when a depot is removed' do
    depot = create(:depot, deliveries_count: 3)
    delivery1 = depot.deliveries[0]
    delivery2 = depot.deliveries[1]
    delivery3 = depot.deliveries[2]
    membership1 = create(:membership, depot: depot)
    membership2 = create(:membership, depot: depot)

    expect(membership1.deliveries).to eq [delivery1, delivery2, delivery3]
    expect(membership2.deliveries).to eq membership1.deliveries

    expect { delivery2.update!(depot_ids: []) }
      .to change { Basket.count }.by(-2)
      .and change { membership1.reload.price }.from(90).to(60)

    expect(membership1.reload.deliveries).to eq [delivery1, delivery3]
    expect(membership2.reload.deliveries).to eq membership1.deliveries
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

  it 'handles date change', freeze: '2020-01-01' do
    delivery_1 = create(:delivery, date: '2020-02-01')
    delivery_2 = create(:delivery, date: '2020-04-01')

    membership1 = create(:membership, started_on: '2020-01-01', ended_on: '2020-05-01')
    membership2 = create(:membership, started_on: '2020-03-01', ended_on: '2020-08-01')

    expect { delivery_1.update!(date: '2020-06-01') }
      .to change { membership1.reload.baskets.size }.from(2).to(1)
      .and change { membership2.reload.baskets.size }.from(1).to(2)
      .and change { membership1.reload.price }.from(60).to(30)
      .and change { membership2.reload.price }.from(30).to(60)
  end

  it 'flags abscent basket when creating them', freeze: '2020-01-01' do
    create(:delivery, date: '2020-02-01')
    membership = create(:membership, started_on: '2020-01-01', ended_on: '2020-06-01')
    create(:absence,
      member: membership.member,
      started_on: '2020-01-15',
      ended_on: '2020-02-15')

    expect(membership.baskets_count).to eq 1
    expect(membership.baskets.first).to be_absent

    delivery = create(:delivery,
      date: '2020-02-15',
      depot_ids: [membership.depot_id])
    membership.reload

    expect(membership.baskets_count).to eq 2
    expect(membership.baskets.last).to have_attributes(
      delivery_id: delivery.id,
      absent: true)
  end

  describe '#shop_open?' do
    specify 'when shop_open is false' do
      delivery = create(:delivery, shop_open: false)

      expect(delivery.shop_open?).to eq false
    end

    specify 'when shop_open is true and no other restriction' do
      delivery = create(:delivery, shop_open: true)

      expect(delivery.shop_open?).to eq true
    end

    specify 'when ACP#shop_delivery_open_delay_in_days is set' do
      Current.acp.update!(shop_delivery_open_delay_in_days: 2)

      delivery = create(:delivery,
        date: '2021-08-10',
        shop_open: true)

      travel_to '2021-08-08 23:59:59 +02' do
        expect(delivery.shop_open?).to eq true
      end
      travel_to '2021-08-09 00:00:00 +02' do
        expect(delivery.shop_open?).to eq false
      end
    end

    specify 'when ACP#shop_delivery_open_last_day_end_time is set' do
      Current.acp.update!(shop_delivery_open_last_day_end_time: '12:00')

      delivery = create(:delivery,
        date: '2021-08-10',
        shop_open: true)

      travel_to '2021-08-10 12:00:00 +02' do
        expect(delivery.shop_open?).to eq true
      end
      travel_to '2021-08-10 12:00:01 +02' do
        expect(delivery.shop_open?).to eq false
      end
    end

    specify 'when both ACP#shop_delivery_open_delay_in_days and ACP#shop_delivery_open_last_day_end_time are set' do
      Current.acp.update!(
        shop_delivery_open_delay_in_days: 1,
        shop_delivery_open_last_day_end_time: '12:30')

      delivery = create(:delivery,
        date: '2021-08-10',
        shop_open: true)

      travel_to '2021-08-09 12:30:00 +02' do
        expect(delivery.shop_open?).to eq true
      end
      travel_to '2021-08-09 12:30:01 +02' do
        expect(delivery.shop_open?).to eq false
      end
    end
  end
end
