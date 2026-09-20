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
