# frozen_string_literal: true

require "test_helper"

class BasketComplementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-01-01"
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "index does not load every join-table row" do
    login admins(:super)

    queries = collect_sql_queries { get basket_complements_path }

    assert_response :success
    assert_select "td", text: "Bread"

    join_loads = queries.select { |sql|
      sql.match?(/SELECT ["`](?:baskets_basket_complements|memberships_basket_complements)["`]\.\*/i)
    }
    assert_empty join_loads, "expected no SELECT * on join tables, got:\n#{join_loads.join("\n")}"
  end

  test "edit shows the default form details placeholder" do
    login admins(:super)
    complement = basket_complements(:bread)

    get edit_basket_complement_path(complement)

    assert_response :success
    assert_select "fieldset[data-controller='form-details-preview']"
    assert_select "input#basket_complement_form_detail_en[placeholder*='4']"
  end

  test "form details preview follows the form price and deliveries" do
    login admins(:super)
    delivery = deliveries(:monday_1)

    get form_details_preview_basket_complements_path, params: {
      basket_complement: {
        price: 8,
        activity_participations_demanded_annually: 0,
        current_delivery_ids: [ delivery.id ]
      }
    }

    assert_response :success
    assert_select "turbo-frame#basket-complement-form-details [data-placeholder-en*='8']"
  end

  private

  def collect_sql_queries
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql]
      queries << sql unless payload[:name] == "SCHEMA" || sql.match?(/\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
