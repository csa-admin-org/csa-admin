# frozen_string_literal: true

require "rails_helper"

describe Membership do
  describe "set activity_participations_demanded_annually" do
    specify "by default" do
      basket_size = create(:basket_size, activity_participations_demanded_annually: 3)
      membership = create(:membership, basket_size_id: basket_size.id)

      expect(membership.activity_participations_demanded_annually).to eq 3
    end

    specify "using basket quantity", freeze: "2023-01-01" do
      basket_size = create(:basket_size, activity_participations_demanded_annually: 3)
      membership = create(:membership,
        basket_quantity: 2,
        basket_size_id: basket_size.id)

      expect(membership.activity_participations_demanded_annually).to eq 2 * 3
    end

    specify "using basket_size and complements" do
      create_deliveries(3)
      basket_size = create(:basket_size, activity_participations_demanded_annually: 3)
      complement_1 = create(:basket_complement, id: 1, activity_participations_demanded_annually: 1)
      complement_2 = create(:basket_complement, id: 2, activity_participations_demanded_annually: 2)

      membership = create(:membership,
        basket_size_id: basket_size.id,
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: 1, quantity: 3 },
          "1" => { basket_complement_id: 2, quantity: 2 }
        })

      expect(membership.activity_participations_demanded_annually).to eq 3 + 3 * 1 + 2 * 2
    end

    specify "when overriden" do
      membership = create(:membership, activity_participations_demanded_annually: 42)
      expect(membership.activity_participations_demanded_annually).to eq 42
    end
  end

  describe "validations" do
    let(:membership) { create(:membership) }

    it "allows only one current memberships per member" do
      new_membership = Membership.new(membership.attributes.except("id"))
      new_membership.validate
      expect(new_membership.errors[:member]).to include "n'est pas disponible"
    end

    it "allows valid attributes" do
      new_membership = Membership.new(membership.attributes.except("id"))
      new_membership.member = create(:member)

      expect(new_membership).to be_valid
    end

    it "allows started_on to be only smaller than ended_on" do
      membership.started_on = Date.new(2015, 2)
      membership.ended_on = Date.new(2015, 1)

      expect(membership).not_to have_valid(:started_on)
      expect(membership).not_to have_valid(:ended_on)
    end

    it "allows started_on to be only on the same year than ended_on" do
      membership.started_on = Date.new(2014, 1)
      membership.ended_on = Date.new(2015, 12)

      expect(membership).not_to have_valid(:started_on)
      expect(membership).not_to have_valid(:ended_on)
    end

    it "validates basket_complement_id uniqueness" do
      create(:basket_complement, id: 1)

      membership = build(:membership,
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: 1 },
          "1" => { basket_complement_id: 1 }
        })
      membership.validate
      mbc = membership.memberships_basket_complements.last

      expect(mbc.errors[:basket_complement_id]).to be_present
    end

    it "prevents date modification when renewed" do
      next_fy = Current.org.fiscal_year_for(Date.today.year + 1)
      create(:delivery, date: next_fy.beginning_of_year)
      membership = create(:membership)
      membership.renew!
      membership.reload

      membership.ended_on = Current.fiscal_year.end_of_year - 4.days
      expect(membership).not_to have_valid(:ended_on)
    end

    it "validates that new_config_from must be in period", freeze: "2022-01-01" do
      membership = create(:membership)

      membership.new_config_from = "2021-12-31"
      expect(membership).not_to have_valid(:new_config_from)
      membership.new_config_from = "2022-01-01"
      expect(membership).to have_valid(:new_config_from)

      membership.new_config_from = "2023-01-01"
      expect(membership).not_to have_valid(:new_config_from)
      membership.new_config_from = "2022-12-31"
      expect(membership).to have_valid(:new_config_from)
    end
  end

  it "creates baskets on creation" do
    basket_size = create(:basket_size)
    depot = create(:depot)

    membership = create(:membership,
      basket_size_id: basket_size.id,
      depot_id: depot.id,
      deliveries_count: 2)

    expect(membership.baskets.count).to eq(2)
    expect(membership.baskets.pluck(:basket_size_id).uniq).to eq [ basket_size.id ]
    expect(membership.baskets.pluck(:depot_id).uniq).to eq [ depot.id ]
  end

  it "creates baskets with complements on creation", freeze: "2023-01-01" do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)
    delivery = create(:delivery, basket_complement_ids: [ 1, 2 ])

    basket_size = create(:basket_size)
    depot = create(:depot)

    membership = create(:membership,
      basket_size_id: basket_size.id,
      depot_id: depot.id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: 1, price: "", quantity: 1 },
        "1" => { basket_complement_id: 2, price: "4.4", quantity: 2 }
      })

    expect(membership.baskets.count).to eq(1)
    basket = membership.baskets.where(delivery: delivery).first
    expect(basket.complement_ids).to match_array [ 1, 2 ]
    expect(basket.complements_price).to eq 3.2 + 2 * 4.4
  end

  it "deletes baskets when started_on and ended_on changes" do
    travel_to "2024-11-01"
    create_deliveries(3)
    create(:delivery, date: Current.fiscal_year.end_of_year)
    membership = create(:membership)
    baskets = membership.baskets
    first_basket = baskets.first
    last_basket = baskets.last

    expect(membership.baskets_count).to eq(4)

    expect {
      membership.update!(
        started_on: first_basket.delivery.date + 1.day,
        ended_on: last_basket.delivery.date - 1.day)
    }
      .to change { membership.reload.baskets_count }.by(-2)
      .and change { membership.reload.price }.by(-60)

    expect { first_basket.reload }.to raise_error ActiveRecord::RecordNotFound
    expect { last_basket.reload }.to raise_error ActiveRecord::RecordNotFound
  end

  it "creates new baskets when started_on and ended_on changes" do
    membership = create(:membership, deliveries_count: 3)
    baskets = membership.baskets
    first_basket = baskets.first
    last_basket = baskets.last

    expect(membership.baskets_count).to eq(3)

    membership.update!(
      started_on: first_basket.delivery.date + 1.day,
      new_config_from: first_basket.delivery.date + 1.day,
      ended_on: last_basket.delivery.date - 1.day)
    expect(membership.baskets_count).to eq(1)

    membership.update!(
      started_on: first_basket.delivery.date - 1.day,
      ended_on: last_basket.delivery.date + 1.day)

    expect(membership.reload.baskets_count).to eq(3)
    new_first_basket = membership.reload.baskets.first
    expect(new_first_basket.basket_size).to eq membership.basket_size
    expect(new_first_basket.depot).to eq membership.depot
    new_last_basket = membership.reload.baskets.last
    expect(new_last_basket.basket_size).to eq membership.basket_size
    expect(new_last_basket.depot).to eq membership.depot
  end

  it "re-creates future baskets by default" do
    membership = travel_to "2022-01-01" do
      create(:delivery, date: "2022-02-01")
      create(:delivery, date: "2022-10-01")
      create(:membership)
    end
      basket_size = membership.basket_size
      depot = membership.depot
      new_basket_size = create(:basket_size)
      new_depot = create(:depot)

    expect(membership.baskets_count).to eq(2)
    beginning_of_year = Date.new(2022, 1, 1)
    middle_of_year = Date.new(2022, 6, 1)
    end_of_year = Date.new(2022, 12, 31)

    travel_to(middle_of_year) do
      membership.reload
      expect(membership.new_config_from).to eq(Date.today)
      membership.update!(
        basket_size_id: new_basket_size.id,
        depot_id: new_depot.id)
    end

    first_half_baskets = membership.baskets.between(beginning_of_year..middle_of_year)
    second_half_baskets = membership.baskets.between(middle_of_year..end_of_year)

    expect(membership.baskets_count).to eq(2)
    expect(first_half_baskets.pluck(:basket_size_id).uniq).to eq [ basket_size.id ]
    expect(second_half_baskets.pluck(:basket_size_id).uniq).to eq [ new_basket_size.id ]
    expect(first_half_baskets.pluck(:depot_id).uniq).to eq [ depot.id ]
    expect(second_half_baskets.pluck(:depot_id).uniq).to eq [ new_depot.id ]
  end

  it "re-creates baskets from a given date" do
    membership = travel_to "2022-01-01" do
      create(:delivery, date: "2022-02-01")
      create(:delivery, date: "2022-10-01")
      create(:membership)
    end
    basket_size = membership.basket_size
    depot = membership.depot
    new_basket_size = create(:basket_size)
    new_depot = create(:depot)

    expect(membership.baskets_count).to eq(2)
    beginning_of_year = Date.new(2022, 1, 1)
    middle_of_year = Date.new(2022, 6, 1)
    end_of_year = Date.new(2022, 12, 31)

    travel_to(end_of_year) do
      membership.update!(
        new_config_from: middle_of_year,
        basket_size_id: new_basket_size.id,
        depot_id: new_depot.id)
    end

    first_half_baskets = membership.baskets.between(beginning_of_year..middle_of_year)
    second_half_baskets = membership.baskets.between(middle_of_year..end_of_year)

    expect(membership.baskets_count).to eq(2)
    expect(first_half_baskets.pluck(:basket_size_id).uniq).to eq [ basket_size.id ]
    expect(second_half_baskets.pluck(:basket_size_id).uniq).to eq [ new_basket_size.id ]
    expect(first_half_baskets.pluck(:depot_id).uniq).to eq [ depot.id ]
    expect(second_half_baskets.pluck(:depot_id).uniq).to eq [ new_depot.id ]
  end

  it "re-creates baskets when only new_config_from change" do
    membership = travel_to "2022-01-01" do
      create(:delivery, date: "2022-02-01")
      create(:delivery, date: "2022-10-01")
      create(:membership)
    end

    expect(membership.baskets_count).to eq(2)
    middle_of_year = Date.new(2022, 6, 1)
    end_of_year = Date.new(2022, 12, 31)

    travel_to(end_of_year) do
      expect {
        membership.update!(
          new_config_from: middle_of_year)
      }. to change { membership.reload.baskets.last.id }
    end

    expect(membership.reload.baskets_count).to eq(2)
  end

  specify "with standard basket_size" do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id)

    expect(membership.basket_sizes_price).to eq 1 * 23.15
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.price).to eq membership.basket_sizes_price
  end

  specify "with depot price" do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      depot_id: create(:depot, price: 2).id)

    expect(membership.basket_sizes_price).to eq 1 * 23.15
    expect(membership.depots_price).to eq 1 * 2
    expect(membership.deliveries_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.depots_price
  end

  specify "with delivery_cycle price" do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      delivery_cycle_id: create(:delivery_cycle, price: 2).id)

    expect(membership.basket_sizes_price).to eq 1 * 23.15
    expect(membership.depots_price).to be_zero
    expect(membership.deliveries_price).to eq 1 * 2
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.deliveries_price
  end

  specify "with custom prices and quantity" do
    membership = create(:membership,
      depot_price: 3.2,
      basket_price: 42,
      basket_quantity: 3)

    expect(membership.basket_sizes_price).to eq 1 * 3 * 42
    expect(membership.depots_price).to eq 1 * 3 * 3.20.to_d
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.depots_price
  end

  specify "with baskets_annual_price_change price" do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      depot_id: create(:depot, price: 2).id,
      baskets_annual_price_change: -11)

    expect(membership.basket_sizes_price).to eq 1 * 23.15
    expect(membership.depots_price).to eq 1 * 2
    expect(membership.baskets_annual_price_change).to eq(-11)
    expect(membership.price)
      .to eq(membership.basket_sizes_price + membership.depots_price - 11)
  end

  specify "with custom basket dynamic extra price" do
    Current.org.update!(
      features: [ :basket_price_extra ],
      basket_price_extra_dynamic_pricing: <<~LIQUID)
        {{ extra | divided_by: 2.0 }}
      LIQUID

    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 15).id,
      basket_quantity: 2,
      depot_id: create(:depot, price: 2).id,
      basket_price_extra: 3)

    expect(membership.baskets_price_extra).to eq 2 * 3 / 2.0
  end

  specify "with basket complements" do
    membership = create(:membership, basket_price: 31, deliveries_count: 40)
    create(:basket_complement, id: 1, price: 2.20)
    create(:basket_complement, id: 2, price: 3.30)

    membership.baskets.first.update!(complement_ids: [ 1, 2 ])
    membership.baskets.second.update!(baskets_basket_complements_attributes: {
      "0" => { basket_complement_id: 1, price: "", quantity: 2 },
      "1" => { basket_complement_id: 2, price: 4, quantity: 3 }
    })
    membership.baskets.third.update!(complement_ids: [ 2 ])

    expect(membership.basket_sizes_price).to eq 40 * 31
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to eq 3 * 2.20 + 2 * 3.3 + 3 * 4
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.basket_complements_price
  end

  specify "with basket complement with deliveries cycle" do
    create(:delivery_cycle, results: :all)
    cycle = create(:delivery_cycle, results: :quarter_1)
    create_deliveries(40)
    create(:basket_complement, id: 1, price: 2.20)
    membership = create(:membership,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: 1, quantity: 1, delivery_cycle: cycle }
      })

    expect(membership.baskets.size).to eq 40
    expect(membership.baskets.map(&:complement_ids).flatten.size).to eq 10
  end

  specify "with basket_complements_annual_price_change price" do
    membership = create(:membership, basket_price: 31, deliveries_count: 40,
      basket_complements_annual_price_change: -12.35)
    create(:basket_complement, id: 1, price: 2.20)
    create(:basket_complement, id: 2, price: 3.30)

    membership.baskets.first.update!(complement_ids: [ 1, 2 ])
    membership.baskets.second.update!(baskets_basket_complements_attributes: {
      "0" => { basket_complement_id: 1, price: "", quantity: 2 },
      "1" => { basket_complement_id: 2, price: 4, quantity: 3 }
    })
    membership.baskets.third.update!(complement_ids: [ 2 ])

    expect(membership.basket_sizes_price).to eq 40 * 31
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.basket_complements_price).to eq 3 * 2.20 + 2 * 3.3 + 3 * 4
    expect(membership.price)
      .to eq membership.basket_sizes_price + membership.basket_complements_price - 12.35
  end

  specify "with activity_participations_annual_price_change price" do
    membership = create(:membership,
      basket_size_id: create(:basket_size, price: 23.125).id,
      depot_id: create(:depot, price: 2).id,
      activity_participations_annual_price_change: -90)

    expect(membership.basket_sizes_price).to eq 1 * 23.15
    expect(membership.depots_price).to eq 1 * 2
    expect(membership.activity_participations_annual_price_change).to eq(-90)
    expect(membership.price)
      .to eq(membership.basket_sizes_price + membership.depots_price - 90)
  end

  specify "salary basket prices" do
    create_deliveries(3)
    create(:basket_complement, id: 1, price: 4.20)
    create(:basket_complement, id: 2, price: 3.30)
    membership = create(:membership, basket_price: 31,
      member: create(:member, salary_basket: true),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: 1, price: "", quantity: 1 }
      })

    membership.baskets.first.update!(complement_ids: [ 1, 2 ])
    membership.baskets.second.update!(baskets_basket_complements_attributes: {
      "0" => {
        id: membership.baskets.second.baskets_basket_complements.first.id,
        basket_complement_id: 1,
        price: "",
        quantity: 2
      },
      "1" => { basket_complement_id: 2, price: 4, quantity: 3 }
    })
    membership.baskets.third.update!(complement_ids: [ 2 ])

    expect(membership.basket_sizes_price).to be_zero
    expect(membership.basket_complements_price).to be_zero
    expect(membership.depots_price).to be_zero
    expect(membership.activity_participations_annual_price_change).to be_zero
    expect(membership.price).to be_zero
  end

  describe "#activity_participations_missing" do
    let(:basket_size) { create(:basket_size, activity_participations_demanded_annually: 3) }

    specify "active membership with no activity participations", freeze: "2024-01-01" do
      Current.org.update!(trial_baskets_count: 0)
      membership = create(:membership, basket_size_id: basket_size.id)

      expect(membership.activity_participations_missing).to eq 3
    end

    specify "when in trial period", freeze: "2024-01-01" do
      Current.org.update!(trial_baskets_count: 1)
      membership = create(:membership, basket_size_id: basket_size.id, deliveries_count: 2)

      expect(membership.trial?).to eq true
      expect(membership.trial_only?).to eq false
      expect(membership.activity_participations_missing).to eq 0
    end

    specify "when in trial period", freeze: "2024-02-01"  do
      Current.org.update!(trial_baskets_count: 1)
      membership = create(:membership, basket_size_id: basket_size.id,
        deliveries_count: 1,
        started_on: "2024-01-01",
        ended_on: "2024-01-31")

      expect(membership.trial?).to eq false
      expect(membership.trial_only?).to eq true
      expect(membership.activity_participations_missing).to eq 0
    end
  end

  describe "set_renew" do
    it "sets renew to true on creation when ended_on is end of year" do
      membership = create(:membership, ended_on: Date.current.end_of_year)
      expect(membership.renew).to eq true
    end

    it "leaves renew to false on creation when ended_on is not end of year" do
      membership = create(:membership, ended_on: Date.current.end_of_year - 1.day)
      expect(membership.renew).to eq false
    end

    it "sets renew to true when ended_on is changed to end of year" do
      membership = create(:membership, ended_on: Date.current.end_of_year - 1.day)
      membership.update!(ended_on: Date.current.end_of_year)
      expect(membership.renew).to eq true
    end

    it "sets renew to false when ended_on is not changed to end of year" do
      travel_to "2024-11-01"
      membership = create(:membership, ended_on: Date.current.end_of_year)
      membership.update!(ended_on: Date.current.end_of_year - 1.day)
      expect(membership.renew).to eq false
    end

    it "sets renew to false when changed manually" do
      membership = create(:membership, ended_on: Date.current.end_of_year)
      membership.update!(renew: false)
      expect(membership.renew).to eq false
    end
  end

  describe "set_activity_participations" do
    before { Current.org.update!(activity_price: 90) }

    specify "when overriden" do
      membership = create(:membership,
        activity_participations_demanded_annually: 0,
        activity_participations_annual_price_change: 180)

      expect(membership).to have_attributes(
        activity_participations_demanded: 0,
        activity_participations_annual_price_change: 180)
    end

    specify "when default" do
      membership = create(:membership)

      expect(membership.activity_participations_demanded_diff_from_default).to eq 0
      expect(membership).to have_attributes(
        activity_participations_demanded: 2,
        activity_participations_annual_price_change: 0)
    end

    specify "when doing more than demanded" do
      membership = create(:membership,
        activity_participations_demanded_annually: 5,
        activity_participations_annual_price_change: nil)

      expect(membership.activity_participations_demanded_diff_from_default).to eq 3
      expect(membership).to have_attributes(
        activity_participations_demanded: 5,
        activity_participations_annual_price_change: -270)
    end

    specify "when doing less than demanded" do
      membership = create(:membership,
        activity_participations_demanded_annually: 1,
        activity_participations_annual_price_change: nil)

      expect(membership.activity_participations_demanded_diff_from_default).to eq -1
      expect(membership).to have_attributes(
        activity_participations_demanded: 1,
        activity_participations_annual_price_change: 90)
    end

    specify "with a diff from default but price change overriden" do
      membership = create(:membership,
        activity_participations_demanded_annually: 6,
        activity_participations_annual_price_change: -100)

      expect(membership.activity_participations_demanded_diff_from_default).to eq 4
      expect(membership).to have_attributes(
        activity_participations_demanded: 6,
        activity_participations_annual_price_change: -100)
    end

    specify "when activity feature is disabled" do
      Current.org.update!(features: [])

      membership = create(:membership,
        activity_participations_annual_price_change: nil,
        activity_participations_demanded: nil)

      expect(membership.activity_participations_demanded_diff_from_default).to eq 0
      expect(membership).to have_attributes(
        activity_participations_demanded: 0,
        activity_participations_annual_price_change: 0)
    end
  end

  it "adds basket_complement to coming baskets when membership is added" do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    delivery_1 = travel_to "2017-01-01" do
      create(:delivery, basket_complement_ids: [ 1 ], date: "2017-03-01")
    end
    travel_to "2017-06-01" do
      delivery_2 = create(:delivery, basket_complement_ids: [ 2 ], date: "2017-07-01")
      delivery_3 = create(:delivery, basket_complement_ids: [ 1, 2 ], date: "2017-08-01")
      delivery_4 = create(:delivery, basket_complement_ids: [ 1 ], date: "2017-08-02")

      membership = create(:membership)

      basket1 = membership.baskets.find_by(delivery: delivery_1)
      basket2 = membership.baskets.find_by(delivery: delivery_2)
      basket3 = membership.baskets.find_by(delivery: delivery_3)
      basket4 = membership.baskets.find_by(delivery: delivery_4)
      basket4.update!(complement_ids: [])

      membership.reload # reset subscribed_basket_complements
      membership.update!(memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: 1, price: "2.9", quantity: 2 }
      })

      basket1.reload
      expect(basket1.complement_ids).to be_empty
      expect(basket1.complements_price).to be_zero

      basket2 = membership.baskets.where(delivery: delivery_2).first
      expect(basket2.complement_ids).to be_empty
      expect(basket2.complements_price).to be_zero

      basket3 = membership.baskets.where(delivery: delivery_3).first
      expect(basket3.complement_ids).to match_array [ 1 ]
      expect(basket3.complements_price).to eq 2.9 * 2

      basket4 = membership.baskets.where(delivery: delivery_4).first
      expect(basket4.complement_ids).to match_array [ 1 ]
      expect(basket4.complements_price).to eq 2.9 * 2

      expect(membership.basket_complements_price).to eq 2.9 * 2 + 2.9 * 2
    end
  end

  it "removes basket_complement to coming baskets when membership is removed" do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    delivery_1 = travel_to "2017-03-01" do
       create(:delivery, basket_complement_ids: [ 1 ], date: "2017-03-01")
    end
    travel_to "2017-05-01" do
      delivery_2 = create(:delivery, basket_complement_ids: [ 1 ], date: "2017-07-01")
      delivery_3 = create(:delivery, basket_complement_ids: [ 1, 2 ], date: "2017-08-01")
      delivery_4 = create(:delivery, basket_complement_ids: [ 2 ], date: "2017-08-02")

      membership = create(:membership,
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: 1, price: "", quantity: 1 },
          "1" => { basket_complement_id: 2, price: "", quantity: 1 }
        })

      basket4 = membership.baskets.find_by(delivery: delivery_4)
      basket4.update!(complement_ids: [ 2 ])

      membership.reload # reset subscribed_basket_complements
      complements = membership.memberships_basket_complements
      membership.update!(memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: 1, price: "", quantity: 1, id: complements.first.id, _destroy: complements.first.id },
        "1" => { basket_complement_id: 2, price: "", quantity: 2, id: complements.last.id }
      })

      basket1 = membership.baskets.find_by(delivery: delivery_1)
      expect(basket1.complement_ids).to match_array [ 1 ]
      expect(basket1.complements_price).to eq 3.2

      basket2 = membership.baskets.find_by(delivery: delivery_2)
      expect(basket2.complement_ids).to be_empty
      expect(basket2.complements_price).to be_zero

      basket3 = membership.baskets.find_by(delivery: delivery_3)
      expect(basket3.complements_price).to eq 2 * 4.5

      basket4 = membership.baskets.find_by(delivery: delivery_4)
      expect(basket4.complement_ids).to match_array [ 2 ]
      expect(basket4.complements_price).to eq 2 * 4.5

      expect(membership.basket_complements_price).to eq 3.2 + 2 * 4.5 + 2 * 4.5
    end
  end

  it "clears member waiting info after creation" do
    create(:basket_complement, id: 1)
    member = create(:member, :waiting, waiting_basket_complement_ids: [ 1 ])

    expect { create(:membership, member: member) }
     .to change { member.waiting_started_at }.to(nil)
     .and change { member.waiting_basket_size_id }.to(nil)
     .and change { member.waiting_depot_id }.to(nil)
     .and change { member.waiting_delivery_cycle_id }.to(nil)
     .and change { member.waiting_basket_complement_ids }.to([])
  end

  it "updates futures basket when configuration change" do
    travel_to("2017-03-01") do
      create(:delivery, date: "2017-03-01")
      create(:delivery, date: "2017-06-15")
      create(:delivery, date: "2017-07-05")
      create(:delivery, date: "2017-08-01")
      create(:delivery, date: "2017-09-01")
    end
    travel_to("2017-06-01") do
      membership = create(:membership,
        started_on: "2017-07-01",
        ended_on: "2017-12-01",
        basket_price: 12)

      expect { membership.update!(basket_price: 13) }
        .to change { membership.reload.baskets.map(&:basket_price) }
        .from([ 12, 12, 12 ]).to([ 13, 13, 13 ])
    end
  end

  specify "updates future baskets price_extra when config change" do
    Current.org.update! features: [ :basket_price_extra ]
    travel_to("2023-03-01") do
      create(:delivery, date: "2023-03-01")
      create(:delivery, date: "2023-06-15")
      create(:delivery, date: "2023-07-05")
      create(:delivery, date: "2023-08-01")
      create(:delivery, date: "2023-09-01")
    end
    travel_to("2023-01-01") do
      membership = create(:membership,
        basket_price_extra: 2,
        deliveries_count: 2)

      expect {
        expect {
          membership.update!(
            new_config_from: "2023-07-01",
            basket_price_extra: 3)
        }
          .to change { membership.baskets.pluck(:price_extra).uniq }
          .from([ 2 ]).to([ 2, 3 ])
      }.to change { membership.reload.baskets_price_extra }.from(5 * 2).to(2 * 2 + 3 * 3)
    end
  end

  it "updates baskets counts after commit" do
    Current.org.update!(trial_baskets_count: 3)

    travel_to "2017-01-01" do
      create(:delivery, date: "2017-01-01")
      create(:delivery, date: "2017-02-01")
      create(:delivery, date: "2017-03-01")
      create(:delivery, date: "2017-04-01")
      create(:delivery, date: "2017-05-01")
      create(:delivery, date: "2017-06-01")
      create(:delivery, date: "2017-07-01")
    end
    travel_to "2017-02-15" do
      membership = create(:membership,
        started_on: "2017-01-01",
        ended_on: "2017-12-01")

      expect(membership.baskets_count).to eq 7
      expect(membership.past_baskets_count).to eq 2
      expect(membership.remaning_trial_baskets_count).to eq 1
      expect(membership).to be_trial
    end
  end

  describe "#update_member_and_baskets" do
    before do
      Current.org.update!(
        trial_baskets_count: 0,
        absences_billed: true)
    end
    specify "updates absent baskets", freeze: "2024-01-01" do
      delivery1 = create(:delivery, date: "2024-01-01")
      delivery2 = create(:delivery, date: "2024-02-01")
      member = create(:member)
      absence = create(:absence,
        member: member,
        started_on: "2024-01-15",
        ended_on: "2024-02-15")
      create(:membership, member: member, started_on: "2024-01-01", ended_on: "2024-12-01")

      expect(member.baskets.first).to have_attributes(
        delivery: delivery1,
        state: "normal",
        billable: true)
      expect(member.baskets.second).to have_attributes(
        delivery: delivery2,
        absence: absence,
        state: "absent",
        billable: true)
    end

    specify "updates trial and absent baskets", freeze: "2024-01-01" do
      Current.org.update!(trial_baskets_count: 2)
      delivery1 = create(:delivery, date: "2024-01-01")
      delivery2 = create(:delivery, date: "2024-02-01")
      delivery3 = create(:delivery, date: "2024-03-01")
      delivery4 = create(:delivery, date: "2024-04-01")
      member = create(:member)
      absence = create(:absence,
        member: member,
        started_on: "2024-01-15",
        ended_on: "2024-02-15")
      create(:membership, member: member, started_on: "2024-01-01", ended_on: "2024-12-01")

      expect(member.baskets.first).to have_attributes(
        delivery: delivery1,
        state: "trial",
        billable: true)
      expect(member.baskets.second).to have_attributes(
        delivery: delivery2,
        absence: absence,
        state: "absent",
        billable: true)
      expect(member.baskets.third).to have_attributes(
        delivery: delivery3,
        state: "trial",
        billable: true)
      expect(member.baskets.fourth).to have_attributes(
        delivery: delivery4,
        state: "normal",
        billable: true)
    end

    specify "marks absent baskets as not billable", freeze: "2024-01-01" do
      Current.org.update!(absences_billed: false)
      delivery1 = create(:delivery, date: "2024-01-01")
      delivery2 = create(:delivery, date: "2024-02-01")
      member = create(:member)
      absence = create(:absence,
        member: member,
        started_on: "2024-01-15",
        ended_on: "2024-02-15")
      create(:membership, member: member, started_on: "2024-01-01", ended_on: "2024-12-01")

      expect(member.baskets.first).to have_attributes(
        delivery: delivery1,
        state: "normal",
        billable: true)
      expect(member.baskets.second).to have_attributes(
        delivery: delivery2,
        absence: absence,
        state: "absent",
        billable: false)
    end

    specify "mark last baskets are absent when all included absence aren't used yet", freeze: "2024-01-01" do
      Current.org.update!(absences_billed: true)
      delivery1 = create(:delivery, date: "2024-01-01")
      delivery2 = create(:delivery, date: "2024-02-01")
      delivery3 = create(:delivery, date: "2024-03-01")
      delivery4 = create(:delivery, date: "2024-04-01")
      delivery5 = create(:delivery, date: "2024-05-01")
      member = create(:member)
      absence = create(:absence,
        member: member,
        started_on: "2024-01-15",
        ended_on: "2024-02-15")
      create(:membership,
        member: member,
        started_on: "2024-01-01",
        ended_on: "2024-12-01",
        absences_included_annually: 3)

      expect(member.baskets.first).to have_attributes(
        delivery: delivery1,
        state: "normal",
        billable: true)
      expect(member.baskets.second).to have_attributes(
        delivery: delivery2,
        absence: absence,
        state: "absent",
        billable: false)
      expect(member.baskets.third).to have_attributes(
        delivery: delivery3,
        state: "normal",
        billable: true)
      expect(member.baskets.fourth).to have_attributes(
        delivery: delivery4,
        absence: nil,
        state: "absent",
        billable: false)
      expect(member.baskets.fifth).to have_attributes(
        delivery: delivery5,
        absence: nil,
        state: "absent",
        billable: false)
    end

    specify "mark last baskets are absent when all included absence aren't used yet", freeze: "2024-01-01" do
      Current.org.update!(absences_billed: true)
      delivery1 = create(:delivery, date: "2024-01-01")
      delivery2 = create(:delivery, date: "2024-02-01")
      delivery3 = create(:delivery, date: "2024-03-01")
      delivery4 = create(:delivery, date: "2024-04-01")
      delivery5 = create(:delivery, date: "2024-05-01")
      member = create(:member)
      absence = create(:absence,
        member: member,
        started_on: "2024-01-15",
        ended_on: "2024-05-15")
      create(:membership,
        member: member,
        started_on: "2024-01-01",
        ended_on: "2024-12-01",
        absences_included_annually: 3)

      expect(member.baskets.first).to have_attributes(
        delivery: delivery1,
        state: "normal",
        billable: true)
      expect(member.baskets.second).to have_attributes(
        delivery: delivery2,
        absence: absence,
        state: "absent",
        billable: false)
      expect(member.baskets.third).to have_attributes(
        delivery: delivery3,
        absence: absence,
        state: "absent",
        billable: false)
      expect(member.baskets.fourth).to have_attributes(
        delivery: delivery4,
        absence: absence,
        state: "absent",
        billable: false)
      expect(member.baskets.fifth).to have_attributes(
        delivery: delivery5,
        absence: absence,
        state: "absent",
        billable: true)
    end

    specify "update baskets counts after commit" do
      Current.org.update!(trial_baskets_count: 3)

      travel_to "2017-01-01" do
        create(:delivery, date: "2017-01-01")
        create(:delivery, date: "2017-02-01")
        create(:delivery, date: "2017-03-01")
        create(:delivery, date: "2017-04-01")
        create(:delivery, date: "2017-05-01")
        create(:delivery, date: "2017-06-01")
        create(:delivery, date: "2017-07-01")
      end
      travel_to "2017-02-15" do
        membership = create(:membership,
          started_on: "2017-01-01",
          ended_on: "2017-12-01")

        expect(membership.baskets_count).to eq 7
        expect(membership.past_baskets_count).to eq 2
        expect(membership.remaning_trial_baskets_count).to eq 1
        expect(membership).to be_trial
      end
    end
  end


  describe "#mark_renewal_as_pending!" do
    it "sets renew to true when previously canceled" do
      membership = create(:membership)
      membership.cancel!

      expect {
        membership.mark_renewal_as_pending!
      }.to change { membership.reload.renew }.from(false).to(true)

      expect(membership).to be_renewal_pending
    end
  end

  describe "#open_renewal!" do
    before { MailTemplate.find_by(title: :membership_renewal).update!(active: true) }

    it "requires future deliveries to be present" do
      membership = create(:membership)

      expect {
        membership.open_renewal!
      }.to raise_error(MembershipRenewal::MissingDeliveriesError)
    end

    it "sets renewal_opened_at" do
      next_fy = Current.org.fiscal_year_for(Date.today.year + 1)
      create(:delivery, date: next_fy.beginning_of_year)
      membership = create(:membership)

      expect {
        membership.open_renewal!
        perform_enqueued_jobs
      }.to change { membership.reload.renewal_opened_at }.from(nil)

      expect(membership).to be_renewal_opened
    end

    it "sends member-renewal email template" do
      next_fy = Current.org.fiscal_year_for(Date.today.year + 1)
      create(:delivery, date: next_fy.beginning_of_year)
      membership = create(:membership)

      expect {
        membership.open_renewal!
        perform_enqueued_jobs
      }.to change { MembershipMailer.deliveries.size }.by(1)
      mail = MembershipMailer.deliveries.last
      expect(mail.subject).to eq "Renouvellement de votre abonnement"
    end
  end

  describe "#renew" do
    it "sets renewal_note attrs" do
      next_fy = Current.org.fiscal_year_for(Date.today.year + 1)
      create(:delivery, date: next_fy.beginning_of_year)
      membership = create(:membership)

      expect {
        membership.renew!(renewal_note: "Je suis super content")
      }.to change(Membership, :count)

      membership.reload
      expect(membership).to be_renewed
      expect(membership.renewal_note).to eq "Je suis super content"
    end
  end

  describe "#cancel" do
    it "sets the membership renew to false" do
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

    it "cancels the membership with a renewal_note" do
      membership = create(:membership)

      expect {
        membership.cancel!(renewal_note: "Je suis pas content")
      }.not_to change(Membership, :count)

      membership.reload
      expect(membership).to be_canceled
      expect(membership.renewal_note).to eq "Je suis pas content"
    end

    it "cancels the membership with a renewal_annual_fee" do
      membership = create(:membership)

      expect {
        membership.cancel!(renewal_annual_fee: "1")
      }.not_to change(Membership, :count)

      membership.reload
      expect(membership).to be_canceled
      expect(membership.renewal_annual_fee).to eq Current.org.annual_fee
    end
  end

  specify "update_renewal_of_previous_membership_after_creation" do
    membership = create(:membership, :last_year)
    membership.update!(renew: true, renewal_opened_at: 1.year.ago)

    expect { create(:membership, member: membership.member) }
      .to change { membership.reload.renewal_state }.from(:renewal_opened).to(:renewed)
  end

  describe "#update_renewal_of_previous_membership_after_deletion" do
    it "clears renewed_at when renewed membership is destroyed" do
      next_fy = Current.org.fiscal_year_for(Date.today.year + 1)
      create(:delivery, date: next_fy.beginning_of_year)
      membership = create(:membership)
      membership.renew!
      renewed_membership = membership.renewed_membership

      expect {
        renewed_membership.destroy!
      }.to change { membership.reload.renewed_at }.to(nil)
    end

    it "cancels previous membership when renewed membership is destroyed and in new fiscal" do
      next_fy = Current.org.fiscal_year_for(Date.today.year + 1)
      create(:delivery, date: next_fy.beginning_of_year)
      membership = create(:membership)
      membership.renew!
      renewed_membership = membership.renewed_membership

      expect {
        travel_to renewed_membership.started_on do
          renewed_membership.destroy!
        end
      }
        .to change { membership.reload.renewed_at }.to(nil)
        .and change { membership.reload.renew }.to(false)
    end
  end

  specify "#keep_renewed_membership_up_to_date!" do
    next_fy = Current.org.fiscal_year_for(Date.today.year + 1)
    create(:delivery, date: next_fy.beginning_of_year)
    membership = create(:membership)
    membership.renew!
    renewed_membership = membership.renewed_membership

    expect {
      membership.update!(billing_year_division: 4)
    }.to change { renewed_membership.reload.billing_year_division }.from(1).to(4)
  end

  describe "#cancel_overcharged_invoice!" do
    before do
      Current.org.update!(
        trial_baskets_count: 0,
        fiscal_year_start_month: 1,
        recurring_billing_wday: 1,
        billing_year_divisions: [ 1, 3 ])
    end

    specify "membership period is reduced" do
      member = create(:member)
      membership = travel_to "2022-01-01" do
        create(:delivery, date: "2022-01-01")
        create(:delivery, date: "2022-06-01")
        create(:membership, member: member, billing_year_division: 1)
      end
      travel_to "2022-05-01" do
        invoice = Billing::Invoicer.force_invoice!(member, send_email: true)
        perform_enqueued_jobs
        membership.update!(ended_on: "2022-05-01")
        expect {
          membership.cancel_overcharged_invoice!
          perform_enqueued_jobs
        }
          .to change { invoice.reload.state }.from("open").to("canceled")
          .and change { membership.reload.invoices_amount }.to(0)
      end
    end

    specify "only cancel the over-paid invoices" do
      member = create(:member)
      membership = travel_to "2022-01-01" do
        create(:membership, member: member, billing_year_division: 3)
      end
      invoice_1 = travel_to "2022-01-01" do
        Billing::Invoicer.force_invoice!(member, send_email: true)
      end
      perform_enqueued_jobs
      invoice_2 = travel_to "2022-05-01" do
        Billing::Invoicer.force_invoice!(member, send_email: true)
      end
      perform_enqueued_jobs
      travel_to "2022-09-01" do
        invoice_3 = Billing::Invoicer.force_invoice!(member, send_email: true)
        perform_enqueued_jobs
        membership.update!(baskets_annual_price_change: -11)
        expect {
          expect { membership.cancel_overcharged_invoice! }
            .to change { invoice_3.reload.state }.from("open").to("canceled")
            .and change { invoice_2.reload.state }.from("open").to("canceled")
            .and change { membership.reload.invoices_amount }.to(10)
        }.not_to change { invoice_1.reload.state }.from("open")
      end
    end

    specify "membership basket price is reduced" do
      member = create(:member)
      membership = travel_to "2022-01-01" do
        create(:membership, member: member, billing_year_division: 1)
      end
      travel_to "2022-02-01" do
        invoice = Billing::Invoicer.force_invoice!(member, send_email: true)
        perform_enqueued_jobs
        membership.baskets.first.update!(basket_price: 5)
        expect { membership.cancel_overcharged_invoice! }
          .to change { invoice.reload.state }.from("open").to("canceled")
          .and change { membership.reload.invoices_amount }.to(0)
      end
    end

    specify "new absent basket not billed are updated" do
      Current.org.update!(absences_billed: false)

      member = create(:member)
      membership = travel_to "2022-01-01" do
        create(:delivery, date: "2022-01-01")
        create(:delivery, date: "2022-06-01")
        create(:membership, member: member, billing_year_division: 1)
      end
      travel_to "2022-02-01" do
        invoice = Billing::Invoicer.force_invoice!(member, send_email: true)
        perform_enqueued_jobs
        expect {
          create(:absence,
            member: member,
            started_on: "2022-05-01",
            ended_on: "2022-07-01")
        }.to change { membership.baskets.billable.count }.by(-1)
        expect(membership.baskets.last).not_to be_billable
        expect { membership.cancel_overcharged_invoice! }
          .to change { invoice.reload.state }.from("open").to("canceled")
          .and change { membership.reload.invoices_amount }.to(0)
      end
    end

    specify "past membership period is not reduced" do
      member = create(:member)
      membership = create(:membership, member: member, billing_year_division: 1)
      invoice = Billing::Invoicer.force_invoice!(member, send_email: true)
      perform_enqueued_jobs
      travel_to(Date.new(Current.fy_year + 1, 12, 15)) do
        membership.baskets.first.update!(basket_price: 5)
        expect { membership.cancel_overcharged_invoice! }
          .not_to change { membership.reload.invoices_amount }
        expect(invoice.reload.state).to eq("open")
      end
    end

    specify "basket complement is added" do
      member = create(:member)
      membership = travel_to "2022-01-01" do
        create(:delivery, date: "2022-01-01")
        create(:delivery, date: "2022-06-01")
        create(:basket_complement, id: 1, price: 4)
        create(:membership,
          member: member,
          billing_year_division: 1,
          memberships_basket_complements_attributes: {
            "0" => { basket_complement_id: 1, quantity: 1 }
          })
      end
      create(:basket_complement, id: 2, price: 4)
      travel_to "2022-05-01" do
        invoice = Billing::Invoicer.force_invoice!(member, send_email: true)
        perform_enqueued_jobs
        membership.reload
        membership.update!(memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: 2, quantity: 1 }
        })
        expect { membership.cancel_overcharged_invoice! }
          .not_to change { invoice.reload.state }.from("open")
      end
    end
  end

  describe "#destroy_or_cancel_invoices!" do
    specify "cancel or destroy membership invoices on destroy" do
      Current.org.update!(
        trial_baskets_count: 0,
        fiscal_year_start_month: 1,
        recurring_billing_wday: 1,
        billing_year_divisions: [ 12 ])
      member = create(:member)
      membership = travel_to "2022-01-01" do
        create(:membership, member: member, billing_year_division: 12)
      end
      sent_invoice = travel_to "2022-02-01" do
        Billing::Invoicer.force_invoice!(member, send_email: true)
      end
      perform_enqueued_jobs
      not_sent_invoice = travel_to "2022-03-01" do
        Billing::Invoicer.force_invoice!(member, send_email: false)
      end
      perform_enqueued_jobs

      travel_to "2022-04-01" do
        expect { membership.destroy }
          .to change { Invoice.not_canceled.reload.count }.by(-2)
          .and change { sent_invoice.reload.state }.from("open").to("canceled")
        expect { not_sent_invoice.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  specify "#can_member_update?" do
    Current.org.update!(membership_depot_update_allowed: false)

    membership = travel_to "2022-12-01" do
      create(:delivery, date: "2022-12-15")
      create(:membership)
    end

    travel_to "2022-12-01" do
      expect(membership.can_member_update?).to be false
    end

    Current.org.update!(membership_depot_update_allowed: true)
    Current.org.update!(basket_update_limit_in_days: 5)

    travel_to "2022-12-10" do
      expect(membership.can_member_update?).to be true
    end
    travel_to "2022-12-11" do
      expect(membership.can_member_update?).to be false
    end

    Current.org.update!(basket_update_limit_in_days: 0)

    travel_to "2022-12-15" do
      expect(membership.can_member_update?).to be true
    end
    travel_to "2022-12-16" do
      expect(membership.can_member_update?).to be false
    end
  end

  specify "#member_update!" do
    depot = create(:depot, price: 2)
    new_depot = create(:depot, price: 3)

    membership = travel_to "2022-01-01" do
      create(:delivery, date: "2022-02-01")
      create(:delivery, date: "2022-03-01")
      create(:delivery, date: "2022-04-01")
      create(:membership, depot: depot)
    end

    Current.org.update!(membership_depot_update_allowed: false)
    expect { membership.member_update!(depot_id: new_depot.id) }
      .to raise_error(RuntimeError, "update not allowed")

    travel_to "2022-02-01" do
      Current.org.update!(
        membership_depot_update_allowed: true,
        basket_update_limit_in_days: 1)
      expect {
        expect { membership.member_update!(depot_id: new_depot.id) }
          .to change { membership.reload.depot_id }.from(depot.id).to(new_depot.id)
          .and change { membership.reload.depot_price }.from(2).to(3)
          .and change { membership.baskets.last.depot }.from(depot).to(new_depot)
          .and change { membership.baskets.last(2).first.depot }.from(depot).to(new_depot)
          .and change { membership.price }.by(2)
      }.not_to change { membership.baskets.first.depot }
    end
  end

  specify "activates pending member on creation" do
    member = create(:member, :waiting)

    expect {
      create(:membership, member: member)
    }.to change { member.reload.state }.from("waiting").to("active")
  end

  specify "can be destroyed" do
    Current.org.update!(features: %w[absence activity])
    membership = create(:membership, absences_included_annually: 3)

    expect {
      membership.destroy
    }.to change { Membership.count }.by(-1)
  end
end
