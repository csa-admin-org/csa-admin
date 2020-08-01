require 'rails_helper'

describe Membership do
  it 'sets activity_participations_demanded_annualy default' do
    basket_size = create(:basket_size, activity_participations_demanded_annualy: 3)
    membership = create(:membership, basket_size_id: basket_size.id)

    expect(membership.activity_participations_demanded_annualy).to eq 3
  end

  it 'sets activity_participations_demanded_annualy default using basket quantity' do
    basket_size = create(:basket_size, activity_participations_demanded_annualy: 3)
    membership = create(:membership,
      basket_quantity: 2,
      basket_size_id: basket_size.id)

    expect(membership.activity_participations_demanded_annualy).to eq 2 * 3
  end

  describe 'validations' do
    let(:membership) { create(:membership) }

    it 'allows only one current memberships per member' do
      new_membership = Membership.new(membership.attributes.except('id'))
      new_membership.validate
      expect(new_membership.errors[:member]).to include "n'est pas disponible"
    end

    it 'allows valid attributes' do
      new_membership = Membership.new(membership.attributes.except('id'))
      new_membership.member = create(:member)

      expect(new_membership).to be_valid
    end

    it 'allows started_on to be only smaller than ended_on' do
      membership.started_on = Date.new(2015, 2)
      membership.ended_on = Date.new(2015, 1)

      expect(membership).not_to have_valid(:started_on)
      expect(membership).not_to have_valid(:ended_on)
    end

    it 'allows started_on to be only on the same year than ended_on' do
      membership.started_on = Date.new(2014, 1)
      membership.ended_on = Date.new(2015, 12)

      expect(membership).not_to have_valid(:started_on)
      expect(membership).not_to have_valid(:ended_on)
    end

    it 'validates basket_complement_id uniqueness' do
      create(:basket_complement, id: 1)

      membership = build(:membership,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 },
          '1' => { basket_complement_id: 1 }
        })
      membership.validate
      mbc = membership.memberships_basket_complements.last

      expect(mbc.errors[:basket_complement_id]).to be_present
    end

    it 'prevents date modification when renewed' do
      next_fy = Current.acp.fiscal_year_for(Date.today.year + 1)
      Delivery.create_all(1, next_fy.beginning_of_year)
      membership = create(:membership)
      membership.renew!
      membership.reload

      membership.ended_on = Current.fiscal_year.end_of_year - 4.days
      expect(membership).not_to have_valid(:ended_on)
    end
  end

  it 'creates baskets on creation' do
    basket_size = create(:basket_size)
    depot = create(:depot, deliveries_count: 42)

    membership = create(:membership,
      basket_size_id: basket_size.id,
      depot_id: depot.id)

    expect(membership.baskets.count).to eq(42)
    expect(membership.baskets.pluck(:basket_size_id).uniq).to eq [basket_size.id]
    expect(membership.baskets.pluck(:depot_id).uniq).to eq [depot.id]
  end

  it 'creates baskets with complements on creation' do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)
    delivery = create(:delivery, basket_complement_ids: [1, 2])

    basket_size = create(:basket_size)
    depot = create(:depot)

    membership = create(:membership,
      basket_size_id: basket_size.id,
      depot_id: depot.id,
      memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: '', quantity: 1 },
        '1' => { basket_complement_id: 2, price: '4.4', quantity: 2 }
      })

    expect(membership.baskets.count).to eq(1)
    basket = membership.baskets.where(delivery: delivery).first
    expect(basket.complement_ids).to match_array [1, 2]
    expect(basket.complements_price).to eq 3.2 + 2 * 4.4
  end

  it 'deletes baskets when started_on and ended_on changes' do
    membership = create(:membership)
    baskets = membership.baskets
    first_basket = baskets.first
    last_basket = baskets.last

    expect(membership.baskets_count).to eq(40)

    expect {
      membership.update!(
        started_on: first_basket.delivery.date + 1.days,
        ended_on: last_basket.delivery.date - 1.days)
    }.to change { membership.reload.price }.by(-60)

    expect(membership.baskets_count).to eq(38)
    expect(first_basket.reload).to be_deleted
    expect(last_basket.reload).to be_deleted
  end

  it 'creates new baskets when started_on and ended_on changes' do
    membership = create(:membership)
    baskets = membership.baskets
    first_basket = baskets.first
    last_basket = baskets.last

    expect(membership.baskets_count).to eq(40)

    membership.update!(
      started_on: first_basket.delivery.date + 1.days,
      ended_on: last_basket.delivery.date - 1.days)
    expect(membership.baskets_count).to eq(38)

    membership.update!(
      started_on: first_basket.delivery.date - 1.days,
      ended_on: last_basket.delivery.date + 1.days)

    expect(membership.reload.baskets_count).to eq(40)
    new_first_basket = membership.reload.baskets.first
    expect(new_first_basket.basket_size).to eq membership.basket_size
    expect(new_first_basket.depot).to eq membership.depot
    new_last_basket = membership.reload.baskets.last
    expect(new_last_basket.basket_size).to eq membership.basket_size
    expect(new_last_basket.depot).to eq membership.depot
  end

  it 're-creates future baskets/depot' do
    membership = create(:membership)
    basket_size = membership.basket_size
    depot = membership.depot
    new_basket_size = create(:basket_size)
    new_depot = create(:depot)

    expect(membership.baskets_count).to eq(40)
    beginning_of_year = Time.current.beginning_of_year
    middle_of_year = Time.current.beginning_of_year + 6.months
    end_of_year = Time.current.end_of_year

    travel_to(middle_of_year) do
      membership.update!(
        basket_size_id: new_basket_size.id,
        depot_id: new_depot.id)
    end

    first_half_baskets = membership.baskets.between(beginning_of_year..middle_of_year)
    second_half_baskets = membership.baskets.between(middle_of_year..end_of_year)

    expect(membership.baskets_count).to eq(40)
    expect(first_half_baskets.pluck(:basket_size_id).uniq).to eq [basket_size.id]
    expect(second_half_baskets.pluck(:basket_size_id).uniq).to eq [new_basket_size.id]
    expect(first_half_baskets.pluck(:depot_id).uniq).to eq [depot.id]
    expect(second_half_baskets.pluck(:depot_id).uniq).to eq [new_depot.id]
  end

  it 're-creates future baskets/depot (with custom deliveries on depot)' do
    membership = create(:membership)
    basket_size = membership.basket_size
    depot = membership.depot
    new_basket_size = create(:basket_size)

    expect(membership.baskets_count).to eq(40)
    beginning_of_year = Time.current.beginning_of_year
    middle_of_year = Time.current.beginning_of_year + 6.months
    end_of_year = Time.current.end_of_year

    coming_deliveries = depot.deliveries.last(5)
    new_depot = create(:depot, delivery_ids: coming_deliveries.map(&:id))

    travel_to(middle_of_year) do
      membership.update!(
        basket_size_id: new_basket_size.id,
        depot_id: new_depot.id)
    end

    first_half_baskets = membership.baskets.between(beginning_of_year..middle_of_year)
    second_half_baskets = membership.baskets.between(middle_of_year..end_of_year)

    expect(membership.baskets_count).to eq(31)
    expect(first_half_baskets.count).to eq(26)
    expect(second_half_baskets.count).to eq(5)

    expect(first_half_baskets.pluck(:basket_size_id).uniq).to eq [basket_size.id]
    expect(second_half_baskets.pluck(:basket_size_id).uniq).to eq [new_basket_size.id]
    expect(first_half_baskets.pluck(:depot_id).uniq).to eq [depot.id]
    expect(second_half_baskets.pluck(:depot_id).uniq).to eq [new_depot.id]
  end

  specify 'with standard basket_size' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id)

    expect(membership.basket_sizes_price).to eq 40 * 23.125
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.price).to eq membership.basket_sizes_price
  end

  specify 'with paid depot' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      depot_id: create(:depot, price: 2).id)

    expect(membership.basket_sizes_price).to eq 40 * 23.125
    expect(membership.depots_price).to eq 40 * 2
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.depots_price
  end

  specify 'with paid depot' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      depot_id: create(:depot, price: 2).id)

    expect(membership.basket_sizes_price).to eq 40 * 23.125
    expect(membership.depots_price).to eq 40 * 2
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.depots_price
  end

  specify 'with custom prices and quantity' do
    membership = create(:membership,
      depot_price: 3.2,
      basket_price: 42,
      basket_quantity: 3)

    expect(membership.basket_sizes_price).to eq 40 * 3 * 42
    expect(membership.depots_price).to eq 40 * 3 * 3.2
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.depots_price
  end

  specify 'with baskets_annual_price_change price' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      depot_id: create(:depot, price: 2).id,
      baskets_annual_price_change: -111)

    expect(membership.basket_sizes_price).to eq 40 * 23.125
    expect(membership.depots_price).to eq 40 * 2
    expect(membership.baskets_annual_price_change).to eq(-111)
    expect(membership.price)
      .to eq(membership.basket_sizes_price + membership.depots_price - 111)
  end

  specify 'with basket complements' do
    membership = create(:membership, basket_price: 31)
    create(:basket_complement, id: 1, price: 2.20)
    create(:basket_complement, id: 2, price: 3.30)

    membership.baskets.first.update!(complement_ids: [1, 2])
    membership.baskets.second.update!(baskets_basket_complements_attributes: {
      '0' => { basket_complement_id: 1, price: '', quantity: 2 },
      '1' => { basket_complement_id: 2, price: 4, quantity: 3 }
    })
    membership.baskets.third.update!(complement_ids: [2])

    expect(membership.basket_sizes_price).to eq 40 * 31
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to eq 3 * 2.20 + 2 * 3.3 + 3 * 4
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.basket_complements_price
  end

  specify 'with basket complements with annual price type' do
    create(:basket_complement, :annual_price_type, id: 1, price: 100)
    create(:basket_complement, id: 2, price: 3.30)
    membership = create(:membership, basket_price: 31,
      memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: '', quantity: 1 }
      })

    membership.baskets.first.update!(complement_ids: [1, 2])
    membership.baskets.second.update!(baskets_basket_complements_attributes: {
      '0' => { basket_complement_id: 1, price: '', quantity: 2 },
      '1' => { basket_complement_id: 2, price: 4, quantity: 3 }
    })
    membership.baskets.third.update!(complement_ids: [2])

    expect(membership.basket_sizes_price).to eq 40 * 31
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to eq 1 * 100 + 2 * 3.3 + 3 * 4
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.basket_complements_price
  end

  specify 'with basket_complements_annual_price_change price' do
    membership = create(:membership, basket_price: 31,
      basket_complements_annual_price_change: -12.35)
    create(:basket_complement, id: 1, price: 2.20)
    create(:basket_complement, id: 2, price: 3.30)

    membership.baskets.first.update!(complement_ids: [1, 2])
    membership.baskets.second.update!(baskets_basket_complements_attributes: {
      '0' => { basket_complement_id: 1, price: '', quantity: 2 },
      '1' => { basket_complement_id: 2, price: 4, quantity: 3 }
    })
    membership.baskets.third.update!(complement_ids: [2])

    expect(membership.basket_sizes_price).to eq 40 * 31
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to eq 3 * 2.20 + 2 * 3.3 + 3 * 4
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.basket_complements_price - 12.35
  end

  specify 'with activity_participations_annual_price_change price' do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      depot_id: create(:depot, price: 2).id,
      activity_participations_annual_price_change: -200)

    expect(membership.basket_sizes_price).to eq 40 * 23.125
    expect(membership.depots_price).to eq 40 * 2
    expect(membership.activity_participations_annual_price_change).to eq(-200)
    expect(membership.price)
      .to eq(membership.basket_sizes_price + membership.depots_price - 200)
  end

  specify 'with only one season' do
    Current.acp.update!(
      summer_month_range_min: 4,
      summer_month_range_max: 9)

    membership = create(:membership,
      basket_price: 30, basket_quantity: 2,
      seasons: ['summer'])

    expect(membership.baskets_count).to eq 40
    expect(membership.basket_sizes_price).to eq 26 * 2 * 30
  end

  specify 'salary basket prices' do
    create(:basket_complement, :annual_price_type, id: 1, price: 100)
    create(:basket_complement, id: 2, price: 3.30)
    membership = create(:membership, basket_price: 31,
      member: create(:member, salary_basket: true),
      memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: '', quantity: 1 }
      })

    membership.baskets.first.update!(complement_ids: [1, 2])
    membership.baskets.second.update!(baskets_basket_complements_attributes: {
      '0' => { basket_complement_id: 1, price: '', quantity: 2 },
      '1' => { basket_complement_id: 2, price: 4, quantity: 3 }
    })
    membership.baskets.third.update!(complement_ids: [2])

    expect(membership.basket_sizes_price).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.price).to be_zero
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

  it 'adds basket_complement to coming baskets when subscription is added' do
    travel_to('2017-06-01') do
      create(:basket_complement, id: 1, price: 3.2)
      create(:basket_complement, id: 2, price: 4.5)
      depot = create(:depot, id: 1, deliveries_count: 0)

      delivery_1 = create(:delivery, depot_ids: [1], basket_complement_ids: [1], date: '2017-03-01')
      delivery_2 = create(:delivery, depot_ids: [1], basket_complement_ids: [2], date: '2017-07-01')
      delivery_3 = create(:delivery, depot_ids: [1], basket_complement_ids: [1, 2], date: '2017-08-01')
      delivery_4 = create(:delivery, depot_ids: [1], basket_complement_ids: [1], date: '2017-08-02')

      membership = create(:membership, depot: depot)

      basket1 = membership.baskets.find_by(delivery: delivery_1)
      basket2 = membership.baskets.find_by(delivery: delivery_2)
      basket3 = membership.baskets.find_by(delivery: delivery_3)
      basket4 = membership.baskets.find_by(delivery: delivery_4)
      basket4.update!(complement_ids: [1, 2])

      membership.reload # reset subscribed_basket_complements
      membership.update!(memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: '2.9', quantity: 2 }
      })

      basket1.reload
      expect(basket1.complement_ids).to be_empty
      expect(basket1.complements_price).to be_zero

      basket2 = membership.baskets.where(delivery: delivery_2).first
      expect(basket2.complement_ids).to be_empty
      expect(basket2.complements_price).to be_zero

      basket3 = membership.baskets.where(delivery: delivery_3).first
      expect(basket3.complement_ids).to match_array [1]
      expect(basket3.complements_price).to eq 2.9 * 2

      basket4 = membership.baskets.where(delivery: delivery_4).first
      expect(basket4.complement_ids).to match_array [1]
      expect(basket4.complements_price).to eq 2.9 * 2

      expect(membership.basket_complements_price).to eq 2.9 * 2 + 2.9 * 2
    end
  end

  it 'adds basket_complement with annual price type to coming baskets when subscription is added' do
    travel_to('2017-06-01') do
      create(:basket_complement, :annual_price_type, id: 1)
      create(:basket_complement, id: 2, price: 4.5)
      depot = create(:depot, id: 1, deliveries_count: 0)

      delivery_1 = create(:delivery, depot_ids: [1], basket_complement_ids: [1], date: '2017-03-01')
      delivery_2 = create(:delivery, depot_ids: [1], basket_complement_ids: [2], date: '2017-07-01')
      delivery_3 = create(:delivery, depot_ids: [1], basket_complement_ids: [1, 2], date: '2017-08-01')
      delivery_4 = create(:delivery, depot_ids: [1], basket_complement_ids: [1], date: '2017-08-02')

      membership = create(:membership, depot: depot)

      basket1 = membership.baskets.find_by(delivery: delivery_1)
      basket2 = membership.baskets.find_by(delivery: delivery_2)
      basket3 = membership.baskets.find_by(delivery: delivery_3)
      basket4 = membership.baskets.find_by(delivery: delivery_4)
      basket4.update!(complement_ids: [1, 2])

      membership.reload # reset subscribed_basket_complements
      membership.update!(memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: 100, quantity: 2 }
      })

      basket1.reload
      expect(basket1.complement_ids).to be_empty
      expect(basket1.complements_price).to be_zero

      basket2 = membership.baskets.where(delivery: delivery_2).first
      expect(basket2.complement_ids).to be_empty
      expect(basket2.complements_price).to be_zero

      basket3 = membership.baskets.where(delivery: delivery_3).first
      expect(basket3.complement_ids).to match_array [1]
      expect(basket3.complements_price).to be_zero

      basket4 = membership.baskets.where(delivery: delivery_4).first
      expect(basket4.complement_ids).to match_array [1]
      expect(basket4.complements_price).to be_zero

      expect(membership.basket_complements_price).to eq 2 * 100
    end
  end

  it 'removes basket_complement to coming baskets when subscription is removed' do
    travel_to('2017-06-01') do
      create(:basket_complement, id: 1, price: 3.2)
      create(:basket_complement, id: 2, price: 4.5)
      depot = create(:depot, id: 1, deliveries_count: 0)

      delivery_1 = create(:delivery, depot_ids: [1], basket_complement_ids: [1], date: '2017-03-01')
      delivery_2 = create(:delivery, depot_ids: [1], basket_complement_ids: [1], date: '2017-07-01')
      delivery_3 = create(:delivery, depot_ids: [1], basket_complement_ids: [1, 2], date: '2017-08-01')
      delivery_4 = create(:delivery, depot_ids: [1], basket_complement_ids: [2], date: '2017-08-02')

      membership = create(:membership, depot: depot)
      membership = create(:membership,
        depot: depot,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, price: '', quantity: 1 },
          '1' => { basket_complement_id: 2, price: '', quantity: 1 }
        })

      basket1 = membership.baskets.find_by(delivery: delivery_1)
      basket2 = membership.baskets.find_by(delivery: delivery_2)
      basket3 = membership.baskets.find_by(delivery: delivery_3)
      basket4 = membership.baskets.find_by(delivery: delivery_4)
      basket4.update!(complement_ids: [1, 2])

      membership.reload # reset subscribed_basket_complements
      complements = membership.memberships_basket_complements
      membership.update!(memberships_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, price: '', quantity: 1, id: complements.first.id, _destroy: complements.first.id },
        '1' => { basket_complement_id: 2, price: '', quantity: 2, id: complements.last.id }
      })

      basket1.reload
      expect(basket1.complement_ids).to match_array [1]
      expect(basket1.complements_price).to eq 3.2

      basket2 = membership.baskets.where(delivery: delivery_2).first
      expect(basket2.complement_ids).to be_empty
      expect(basket2.complements_price).to be_zero

      basket3 = membership.baskets.where(delivery: delivery_3).first
      expect(basket3.complement_ids).to match_array [2]
      expect(basket3.complements_price).to eq 2 * 4.5

      basket4 = membership.baskets.where(delivery: delivery_4).first
      expect(basket4.complement_ids).to match_array [2]
      expect(basket4.complements_price).to eq 2 * 4.5

      expect(membership.basket_complements_price).to eq 3.2 + 2 * 4.5 + 2 * 4.5
    end
  end

  it 'clears member waiting info after creation' do
    create(:basket_complement, id: 1)
    member = create(:member, :waiting, waiting_basket_complement_ids: [1])

    expect { create(:membership, member: member) }
     .to change { member.waiting_started_at }.to(nil)
     .and change { member.waiting_basket_size_id }.to(nil)
     .and change { member.waiting_depot_id }.to(nil)
     .and change { member.waiting_basket_complement_ids }.to([])
  end

  it 'updates futures basket when subscription change' do
    travel_to('2017-06-01') do
      create(:delivery, date: '2017-03-01')
      create(:delivery, date: '2017-06-15')
      create(:delivery, date: '2017-07-05')
      create(:delivery, date: '2017-08-01')
      create(:delivery, date: '2017-09-01')
      depot = create(:depot, delivery_ids: Delivery.pluck(:id))

      membership = create(:membership,
        depot: depot,
        started_on: '2017-07-01',
        ended_on: '2017-12-01',
        basket_price: 12)

      expect { membership.update!(basket_price: 13) }
        .to change { membership.reload.baskets.map(&:basket_price) }
        .from([12, 12, 12]).to([13, 13, 13])
    end
  end

  it 'updates baskets counts after commit' do
    Current.acp.update!(trial_basket_count: 3)

    create(:delivery, date: '2017-01-01')
    create(:delivery, date: '2017-02-01')
    create(:delivery, date: '2017-03-01')
    create(:delivery, date: '2017-04-01')
    create(:delivery, date: '2017-05-01')
    create(:delivery, date: '2017-06-01')
    create(:delivery, date: '2017-07-01')
    depot = create(:depot, delivery_ids: Delivery.pluck(:id))

    travel_to('2017-02-15') do
      membership = create(:membership,
        depot: depot,
        started_on: '2017-01-01',
        ended_on: '2017-12-01')

      expect(membership.baskets_count).to eq 7
      expect(membership.delivered_baskets_count).to eq 2
      expect(membership.remaning_trial_baskets_count).to eq 1
      expect(membership).to be_trial
    end
  end

  describe '#enable_renewal!' do
    it 'sets renew to true when previously canceled' do
      membership = create(:membership)
      membership.cancel!

      expect {
        membership.enable_renewal!
      }.to change { membership.reload.renew }.from(false).to(true)
    end
  end

  describe '#open_renewal!' do
    it 'requires future deliveries to be present' do
      membership = create(:membership)

      expect {
        membership.open_renewal!
      }.to raise_error(MembershipRenewal::MissingDeliveriesError)
    end

    it 'sets renewal_opened_at' do
      next_fy = Current.acp.fiscal_year_for(Date.today.year + 1)
      Delivery.create_all(1, next_fy.beginning_of_year)
      membership = create(:membership)

      expect {
        membership.open_renewal!
      }.to change { membership.reload.renewal_opened_at }.from(nil)

      expect(membership).to be_renewal_open
    end
  end

  describe '#renew' do
    it 'sets renewal_note attrs' do
      next_fy = Current.acp.fiscal_year_for(Date.today.year + 1)
      Delivery.create_all(1, next_fy.beginning_of_year)
      membership = create(:membership)

      expect {
        membership.renew!(renewal_note: 'Je suis super content')
      }.to change(Membership, :count)

      membership.reload
      expect(membership).to be_renewed
      expect(membership.renewal_note).to eq 'Je suis super content'
    end
  end

  describe '#cancel' do
    it 'sets the membership renew to false' do
      membership = create(:membership)
      membership.update_column(:renewal_opened_at, Time.current)

      expect {
        membership.cancel!
      }.not_to change(Membership, :count)

      membership.reload
      expect(membership).to be_canceled
      expect(membership.renew).to eq false
      expect(membership.renewal_opened_at).to be_nil
      expect(membership.renewed_at).to be_nil
    end

    it 'cancels the membership with a renewal_note' do
      membership = create(:membership)

      expect {
        membership.cancel!(renewal_note: 'Je suis pas content')
      }.not_to change(Membership, :count)

      membership.reload
      expect(membership).to be_canceled
      expect(membership.renewal_note).to eq 'Je suis pas content'
    end

    it 'cancels the membership with a renewal_annual_fee' do
      membership = create(:membership)

      expect {
        membership.cancel!(renewal_annual_fee: '1')
      }.not_to change(Membership, :count)

      membership.reload
      expect(membership).to be_canceled
      expect(membership.renewal_annual_fee).to eq Current.acp.annual_fee
    end
  end

  describe '#open_renewal_of_previous_membership' do
    it 'clears renewed_at when renewed membership is destroyed' do
      next_fy = Current.acp.fiscal_year_for(Date.today.year + 1)
      Delivery.create_all(1, next_fy.beginning_of_year)
      membership = create(:membership)
      membership.renew!
      renewed_membership = membership.renewed_membership

      expect {
        renewed_membership.destroy!
      }.to change { membership.reload.renewed_at }.to(nil)
    end
  end
end
