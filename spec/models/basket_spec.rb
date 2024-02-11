require "rails_helper"

describe Basket do
  it "sets prices before validation" do
    basket = build(:basket,
      basket_size: create(:basket_size, price: 30),
      depot: create(:depot, price: 5))
    basket.validate

    expect(basket.basket_price).to eq 30
    expect(basket.depot_price).to eq 5
  end

  it "validates basket_complement_id uniqueness" do
    create(:basket_complement, id: 1)

    basket = build(:basket,
      baskets_basket_complements_attributes: {
        "0" => { basket_complement_id: 1 },
        "1" => { basket_complement_id: 1 }
      })
    basket.validate
    bbc = basket.baskets_basket_complements.last

    expect(bbc.errors[:basket_complement_id]).to be_present
  end

  it "validates delivery is in membership date range", freeze: "2022-01-01" do
    delivery = create(:delivery, date: "2022-01-01")
    create(:delivery, date: "2022-03-01")
    membership = build(:membership, started_on: "2022-02-01")

    basket = build(:basket, membership: membership, delivery: delivery)
    basket.validate

    expect(basket.errors[:delivery]).to be_present
  end

  it "updates basket complement_prices when created" do
    basket = create(:membership).baskets.first
    create(:basket_complement, id: 42, price: 3.2)

    expect {
      basket.update!(complement_ids: [ 42 ])
    }.to change(basket, :complements_price).from(0).to(3.2)
  end

  it "removes basket complement_prices when destroyed" do
    basket = create(:membership).baskets.first
    create(:basket_complement, id: 42, price: 3.2)
    create(:basket_complement, id: 47, price: 4.5)
    basket.update!(complement_ids: [ 47, 42 ])

    expect {
      basket.update!(complement_ids: [ 47 ])
    }.to change(basket, :complements_price).from(3.2 + 4.5).to(4.5)
  end

  it "sets basket_complement on creation when its match membership subscriptions", freeze: "2022-01-01", sidekiq: :inline do
    create(:basket_complement, id: 1, price: 3.2)
    create(:basket_complement, id: 2, price: 4.5)

    create(:delivery)
    membership_1 = create(:membership, subscribed_basket_complement_ids: [ 1, 2 ])
    membership_2 = create(:membership, subscribed_basket_complement_ids: [ 2 ])
    delivery = create(:delivery, basket_complement_ids: [ 1, 2 ])

    basket1 = delivery.baskets.find_by(membership: membership_1)
    expect(basket1.complement_ids).to match_array [ 1, 2 ]
    expect(basket1.complements_price).to eq 3.2 + 4.5

    basket2 = delivery.baskets.find_by(membership: membership_2)
    expect(basket2.complement_ids).to match_array [ 2 ]
    expect(basket2.complements_price).to eq 4.5
  end

  specify "#can_member_update?" do
    Current.acp.update!(membership_depot_update_allowed: false)

    delivery = build(:delivery, date: "2022-12-15")
    basket = build(:basket, delivery: delivery)

    travel_to "2022-12-01" do
      expect(basket.can_member_update?).to be false
    end

    Current.acp.update!(membership_depot_update_allowed: true)
    Current.acp.update!(basket_update_limit_in_days: 5)

    travel_to "2022-12-10" do
      expect(basket.can_member_update?).to be true
    end
    travel_to "2022-12-11" do
      expect(basket.can_member_update?).to be false
    end

    Current.acp.update!(basket_update_limit_in_days: 0)

    travel_to "2022-12-15" do
      expect(basket.can_member_update?).to be true
    end
    travel_to "2022-12-16" do
      expect(basket.can_member_update?).to be false
    end

    travel_to "2022-12-15" do
      basket.state = "absent"
      expect(basket.can_member_update?).to be false
    end
  end

  specify "#member_update!" do
    depot = create(:depot, price: 2)
    new_depot = create(:depot, price: 3)
    basket = create(:membership, depot: depot).baskets.first

    travel_to Time.current.beginning_of_year do
      Current.acp.update!(membership_depot_update_allowed: false)
      expect { basket.member_update!(depot_id: new_depot.id) }
        .to raise_error(RuntimeError, "update not allowed")

      Current.acp.update!(membership_depot_update_allowed: true)
      expect { basket.member_update!(depot_id: new_depot.id) }
        .to change { basket.reload.depot }.from(depot).to(new_depot)
        .and change { basket.reload.depot_price }.from(2).to(3)
        .and change { basket.reload.membership.price }.by(1)
    end
  end

  describe "#calculate_price_extra" do
    before { Current.acp.update! features: [ :basket_price_extra ] }
    let(:membership) { create(:membership) }
    let(:basket) {
      basket = Basket.new(
        membership: membership,
        quantity: 2,
        basket_price: 19,
        price_extra: 2.42)
    }

    specify "without basket_price_extra feature" do
      Current.acp.update! features: []

      expect(basket.send(:calculate_price_extra)).to eq 0
    end

    specify "when basket_price is zero" do
      basket.basket_price = 0
      expect(basket.send(:calculate_price_extra)).to eq 0
    end

    specify "when quantity is zero" do
      basket.quantity = 0
      expect(basket.send(:calculate_price_extra)).to eq 2.42
    end

    specify "when no membership basket_price_extra" do
      basket.price_extra = 0
      expect(basket.send(:calculate_price_extra)).to eq 0
    end

    specify "when non billable basket" do
      Current.acp.update!(absences_billed: false)
      basket.state = "absent"
      expect(basket.send(:calculate_price_extra)).to eq 2.42
    end

    specify "without dynamic pricing" do
      expect(basket.send(:calculate_price_extra)).to eq 2.42
    end

    specify "with dynamic pricing based on basket_size" do
      basket_1 = Basket.new(
        basket_size_id: 1,
        basket_price: 19,
        price_extra: 2,
        quantity: 2,
        membership: membership)
      basket_2 = Basket.new(
        basket_size_id: 2,
        basket_price: 33,
        price_extra: 2,
        quantity: 2,
        membership: membership)

      Current.acp.update!(basket_price_extra_dynamic_pricing: <<~LIQUID)
        {% if basket_size_id == 1 %}
          {{ 15 | minus: 10 | divided_by: 3.0 }}
        {% else %}
          2.5
        {% endif %}
      LIQUID

      expect(basket_1.send(:calculate_price_extra)).to eq 5 / 3.0
      expect(basket_2.send(:calculate_price_extra)).to eq 2.5
    end

    specify "with dynamic pricing based on basket_size and complements prices" do
      Current.acp.update!(basket_price_extra_dynamic_pricing: <<~LIQUID)
        {% assign price = basket_price | plus: complements_price %}
        {{ price | divided_by: 100.0 | times: extra }}
      LIQUID

      membership = create(:membership)
      complement_1 = create(:basket_complement)
      complement_2 = create(:basket_complement)
      basket = membership.baskets.first
      basket.update!(
        basket_price: 20.5,
        price_extra: -20,
        baskets_basket_complements_attributes: {
          "0" => { basket_complement_id: complement_1.id, quantity: 2, price: 3.3 },
          "1" => { basket_complement_id: complement_2.id, quantity: 1, price: 4.2 }
        })

      expect(basket.calculated_price_extra).to eq ((20.5 + 2 * 3.3 + 1 * 4.2) / 100.0 * -20)
    end

    specify "with dynamic pricing based on deliveries count and extra", freeze: "2022-01-01" do
      create_deliveries(3)
      membership = create(:membership)
      basket = Basket.new(
        basket_size_id: 1,
        basket_price: 19,
        price_extra: 10,
        quantity: 2,
        membership: create(:membership))

      Current.acp.update!(basket_price_extra_dynamic_pricing: <<~LIQUID)
        {{ extra | divided_by: deliveries_count }}
      LIQUID

      expect(basket.send(:calculate_price_extra)).to eq 10 / 3.0
    end
  end
end
