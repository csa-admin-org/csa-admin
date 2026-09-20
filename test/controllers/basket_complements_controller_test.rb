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

  test "index does not SELECT all baskets_basket_complements rows" do
    login admins(:super)
    seed_many_baskets_basket_complements!

    queries = collect_sql_queries { get basket_complements_path }

    assert_response :success
    assert_select "td", text: "Bread"
    assert_select "td", text: "Cheese"
    assert_select "td", text: "Eggs"

    unbounded = queries.select { |sql| unbounded_join_table_load?(sql) }
    assert_empty unbounded,
      "expected no unbounded join-table loads on index, got:\n#{unbounded.join("\n")}"
  end

  test "index join-table queries stay bounded as baskets_basket_complements grow" do
    login admins(:super)

    few_queries = collect_sql_queries { get basket_complements_path }
    assert_response :success

    seed_many_baskets_basket_complements!
    many_queries = collect_sql_queries { get basket_complements_path }
    assert_response :success

    assert_equal query_signatures(few_queries).size, query_signatures(many_queries).size
    assert_empty many_queries.select { |sql| unbounded_join_table_load?(sql) }
  end

  private

  def seed_many_baskets_basket_complements!
    now = Time.current
    existing = BasketsBasketComplement.pluck(:basket_id, :basket_complement_id)
    pairs = Basket.pluck(:id).product(BasketComplement.kept.pluck(:id)) - existing
    return if pairs.empty?

    BasketsBasketComplement.insert_all(pairs.map { |basket_id, basket_complement_id|
      {
        basket_id: basket_id,
        basket_complement_id: basket_complement_id,
        quantity: 1,
        price: 1,
        created_at: now,
        updated_at: now
      }
    })
  end

  def collect_sql_queries
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql]
      queries << sql unless payload[:name] == "SCHEMA" || sql.match?(/\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  def unbounded_join_table_load?(sql)
    return false unless sql.match?(
      /SELECT ["`](?:baskets_basket_complements|memberships_basket_complements)["`]\.\*/i)
    return false if sql.match?(/\bLIMIT\b/i)
    return false if sql.match?(/\bCOUNT\s*\(/i)

    true
  end

  def query_signatures(queries)
    queries.select { |sql|
      sql.match?(/FROM ["`](?:baskets_basket_complements|memberships_basket_complements)["`]/i)
    }.map { |sql| sql.gsub(/\d+/, "N") }
  end
end
