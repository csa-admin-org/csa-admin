# frozen_string_literal: true

require "test_helper"

class Members::MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
  end

  test "new succeeds when nested member params are empty" do
    get new_members_member_path, params: { member: {} }

    assert_response :success
  end

  test "new renders required card fields for a visible reduction" do
    org(features: Current.org.features | [ "price_reductions" ])
    card = PriceReductionCard.create!(
      names: { "en" => "Culture card" },
      require_name: true,
      require_number: true,
      require_expires_on: true)
    PriceReduction.create!(
      names: { "en" => "Caritas" },
      percentage: 10,
      price_reduction_card: card,
      visible: true)

    get new_members_member_path

    assert_response :success
    assert_select "legend.form-label", text: "Price reduction"
    assert_select "legend.form-label + .form-richtext", count: 0
    assert_select ".choice-title", text: "Caritas"
    assert_select ".choice-details", text: '10%, Card "Culture card" required'
    assert_select "label[for=member_waiting_price_reduction_id]" do
      assert_select "input[type=radio][value=''][checked][id=member_waiting_price_reduction_id]"
      assert_select ".choice-title", text: "No reduction"
    end
    assert_select ".choice-title", text: "No reduction"
    assert_select "fieldset[data-price-reduction-target=card][disabled]" do
      assert_select "legend", text: "Card: Culture card"
      assert_select ".reduction-card-copy", text: "Enter the card details required for the selected reduction."
      assert_select "input[name='member[member_cards_attributes][][name]'][data-action='form-pricing#refresh']"
      assert_select "input[name='member[member_cards_attributes][][number]']"
      assert_select "input[name='member[member_cards_attributes][][expires_on]']"
      assert_select "input[name='member[member_cards_attributes][][price_reduction_card_id]'][value=?]", card.id.to_s
    end
  end

  test "new ignores a hidden reduction and cards that were not selected" do
    org(features: Current.org.features | [ "price_reductions" ])
    card = PriceReductionCard.create!(
      names: { "en" => "Culture card" },
      require_name: true,
      require_number: true,
      require_expires_on: true)
    hidden = PriceReduction.create!(
      names: { "en" => "Hidden" },
      percentage: 20,
      price_reduction_card: card,
      visible: false)
    visible = PriceReduction.create!(
      names: { "en" => "Caritas" },
      percentage: 10,
      visible: true)

    get new_members_member_path, params: {
      member: {
        waiting_price_reduction_id: hidden.id,
        member_cards_attributes: [
          { price_reduction_card_id: card.id, name: "Should not stick" }
        ]
      }
    }

    assert_response :success
    assert_select "input[type=radio][name='member[waiting_price_reduction_id]'][value=?]", hidden.id.to_s, count: 0
    assert_select "input[type=radio][name='member[waiting_price_reduction_id]'][value=?]:not([checked])", visible.id.to_s
    assert_select "input[name='member[member_cards_attributes][][name]'][value='Should not stick']", count: 0
  end

  test "new keeps a visible reduction and its card" do
    org(features: Current.org.features | [ "price_reductions" ])
    card = PriceReductionCard.create!(
      names: { "en" => "Culture card" },
      require_name: true)
    reduction = PriceReduction.create!(
      names: { "en" => "Caritas" },
      percentage: 10,
      price_reduction_card: card,
      visible: true)

    get new_members_member_path, params: {
      member: {
        waiting_price_reduction_id: reduction.id,
        member_cards_attributes: {
          "0" => { price_reduction_card_id: card.id, name: "Ada" }
        }
      }
    }

    assert_response :success
    assert_select "input[type=radio][name='member[waiting_price_reduction_id]'][value=?][checked]", reduction.id.to_s
    assert_select "input[name='member[member_cards_attributes][][name]'][value=Ada]"
  end

  test "new omits a delivery cycle with no deliveries in the membership start year" do
    travel_to "2024-07-01"
    Current.reset
    empty_cycle = create_delivery_cycle(
      names: { en: "Early Season" },
      wdays: [ 4 ],
      last_cweek: 14,
      depots: Depot.kept.to_a)

    get new_members_member_path

    assert_response :success
    assert_equal 0, empty_cycle.deliveries_count_for(Delivery.next.fy_year)
    assert_select "input[type=radio][name='member[waiting_delivery_cycle_id]'][value=?]",
      empty_cycle.id, count: 0
    assert_select "input[type=radio][name='member[waiting_delivery_cycle_id]']"
  end

  test "new renders no delivery cycle choices when none have start-year deliveries" do
    travel_to "2024-07-01"
    Current.reset
    DeliveryCycle.kept.find_each do |cycle|
      cycle.update_column(:deliveries_counts, {
        Delivery.next.fy_year.to_s => 0,
        Current.fy_year.to_s => 12
      })
    end

    get new_members_member_path

    assert_response :success
    assert_select "input[name='member[waiting_delivery_cycle_id]']", count: 0
  end

  test "new omits a depot whose cycles have no deliveries in the membership start year" do
    travel_to "2024-07-01"
    Current.reset
    empty_cycle = create_delivery_cycle(
      names: { en: "Early Season" },
      wdays: [ 4 ],
      last_cweek: 14)
    depot = Depot.create!(
      name: "Seasonal only",
      city: "City",
      zip: "1000",
      price: 0,
      delivery_cycles: [ empty_cycle ])

    get new_members_member_path

    assert_response :success
    assert_select "input[type=radio][name='member[waiting_depot_id]'][value=?]",
      depot.id, count: 0
    assert_select "input[type=radio][name='member[waiting_depot_id]']"
  end
end
