# frozen_string_literal: true

require "test_helper"

class Members::DeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup { host! "members.acme.test" }

  test "past basket contents stay one query as baskets are added" do
    travel_to "2024-06-07"
    org(
      features: Current.org.features | [ :basket_content ],
      basket_content_member_visible: true,
      basket_content_member_visible_hours_before: 12,
      basket_content_member_display_quantity: true)
    create_basket_content(
      delivery: deliveries(:thursday_7),
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 1000 },
      depots: Depot.all,
      unit: "kg")
    create_basket_content(
      delivery: deliveries(:thursday_8),
      product: basket_content_products(:cucumbers),
      basket_size_ids_quantities: { large_id => 3 },
      depots: Depot.all,
      unit: "pc")
    create_basket_content(
      delivery: deliveries(:thursday_9),
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 500 },
      depots: Depot.all,
      unit: "kg")
    login(members(:jane))

    queries = capture_selects {
      get members_deliveries_path(all_past_deliveries: true)
    }

    assert_response :success
    past_baskets = css_select("#past_deliveries .basket").size
    assert_operator past_baskets, :>, 3
    assert_select "details.basket-contents-details", count: 3
    assert_equal 1, queries["basket_contents"].size, queries["basket_contents"].join("\n")
    assert_equal 1, queries["basket_content_products"].size, queries["basket_content_products"].join("\n")
    assert_operator queries["depots"].size, :<, past_baskets
    assert_operator queries["basket_contents_depots"].size, :<, past_baskets
  end

  test "past zero-quantity basket does not show contents" do
    travel_to "2024-04-08"
    org(
      features: Current.org.features | [ :basket_content ],
      basket_content_member_visible: true,
      basket_content_member_visible_hours_before: 12)
    basket = baskets(:jane_1)
    basket.update_columns(quantity: 0)
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 1000 },
      depots: Depot.all,
      unit: "kg")
    login(members(:jane))

    get members_deliveries_path

    assert_response :success
    assert_select "#past_deliveries #basket_#{basket.id}"
    assert_select "#past_deliveries details.basket-contents-details", count: 0
  end

  private

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  def capture_selects
    queries = Hash.new { |hash, key| hash[key] = [] }
    callback = ->(*, payload) {
      sql = payload[:sql].to_s
      next if payload[:name] == "SCHEMA" || !sql.match?(/\ASELECT/i)

      table = sql[/FROM\s+["`]?(basket_contents_depots|basket_content_products|basket_contents|depots)["`]?/i, 1]
      queries[table.downcase] << sql if table
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
