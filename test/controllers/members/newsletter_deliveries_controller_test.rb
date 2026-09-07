# frozen_string_literal: true

require "test_helper"

class Members::NewsletterDeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  def login_as_admin_originated(member, admin: admins(:ultra))
    session = Session.create!(
      admin: admin,
      member: member,
      email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  test "index lists the latest processed newsletter deliveries" do
    login(members(:john))

    get members_newsletter_deliveries_path

    assert_response :success
    assert_select ".newsletter-title", text: "Subject John Doe"
    assert_select ".newsletter-date", text: /1 April 2024/
  end

  test "index query count stays bounded as newsletter deliveries grow" do
    member = members(:john)
    login(member)

    create_newsletter_deliveries!(member, 25)
    few_queries = collect_sql_queries { get members_newsletter_deliveries_path }
    assert_response :success
    assert_bounded_newsletter_index_queries(few_queries)

    create_newsletter_deliveries!(member, 40, start_at: 1.hour.ago)
    many_queries = collect_sql_queries { get members_newsletter_deliveries_path }
    assert_response :success
    assert_bounded_newsletter_index_queries(many_queries)

    assert_equal query_signatures(few_queries).size, query_signatures(many_queries).size
    assert_equal newsletter_loads(few_queries).size, newsletter_loads(many_queries).size
    assert_equal mail_delivery_loads(few_queries).size, mail_delivery_loads(many_queries).size
  end

  test "index paginates without loading every delivery" do
    member = members(:john)
    login(member)
    create_newsletter_deliveries!(
      member,
      Members::NewsletterDeliveriesController::PER_PAGE,
      start_at: 1.hour.from_now)

    get members_newsletter_deliveries_path

    assert_response :success
    assert_select ".newsletter-title", text: "Extra 0"
    assert_select ".newsletter-title", text: "Subject John Doe", count: 0
    assert_select "#show-more a[href*='offset=20']"

    get members_newsletter_deliveries_path(offset: 20, format: :turbo_stream)

    assert_response :success
    assert_includes response.body, "Subject John Doe"
  end

  test "index shows the member email in the unsubscribe banner for an admin-originated session" do
    member = members(:john)
    EmailSuppression.suppress!(member.emails_array.first,
      stream_id: "broadcast",
      reason: "ManualSuppression",
      origin: "Customer")

    login_as_admin_originated(member)

    get members_newsletter_deliveries_path

    assert_response :success
    assert_select "form[action='#{members_email_suppression_path}']"
    assert_includes response.body, member.emails_array.first
  end

  test "resubscribe is blocked for an admin-originated session" do
    member = members(:john)
    EmailSuppression.suppress!(member.emails_array.first,
      stream_id: "broadcast",
      reason: "ManualSuppression",
      origin: "Customer")
    login_as_admin_originated(member)

    assert_no_difference -> {
      EmailSuppression.active.where(email: member.emails_array.first, stream_id: "broadcast").count
    } do
      delete members_email_suppression_path,
        headers: { "HTTP_REFERER" => members_newsletter_deliveries_path }
    end

    assert_redirected_to members_newsletter_deliveries_path
    assert_equal I18n.t("members.read_only_sessions.alert"), flash[:alert]
  end

  private

  def create_newsletter_deliveries!(member, count, start_at: Time.current)
    newsletter = newsletters(:sent)
    rows = count.times.map { |i|
      {
        mailable_type: "Newsletter",
        mailable_ids: [ newsletter.id ],
        action: "newsletter",
        member_id: member.id,
        subject: "Extra #{i}",
        state: "delivered",
        content: "<html>#{"x" * 2_000}</html>",
        created_at: start_at - i.minutes,
        updated_at: start_at - i.minutes
      }
    }
    MailDelivery.insert_all(rows)
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

  def mail_delivery_loads(queries)
    queries.select { |sql|
      sql.match?(/SELECT .+FROM ["`]mail_deliveries["`]/i) &&
        !sql.match?(/SELECT 1 AS one/i) &&
        !sql.match?(/COUNT\(/i)
    }
  end

  def newsletter_loads(queries)
    queries.select { |sql| sql.match?(/SELECT .+FROM ["`]newsletters["`]/i) }
  end

  def query_signatures(queries)
    (mail_delivery_loads(queries) + newsletter_loads(queries)).map { |sql|
      sql.gsub(/\d+/, "N")
    }
  end

  def assert_bounded_newsletter_index_queries(queries)
    loads = mail_delivery_loads(queries)
    assert_operator loads.size, :<=, 2,
      "expected bounded MailDelivery loads, got:\n#{loads.join("\n")}"
    loads.each do |sql|
      assert_match(/LIMIT/i, sql)
    end

    page_loads = loads.select { |sql| sql.match?(/OFFSET/i) }
    assert_equal 1, page_loads.size, "expected one paginated MailDelivery load, got:\n#{loads.join("\n")}"
    page_loads.each do |sql|
      assert_no_match(/\bSELECT\s+(?:["`]?\w+["`]?\.)?\*/i, sql)
      assert_match(/["`]subject["`]/, sql)
      assert_no_match(/["`]content["`]/, sql)
    end

    newsletter_sql = newsletter_loads(queries)
    assert_operator newsletter_sql.size, :<=, 2,
      "expected bounded Newsletter loads, got:\n#{newsletter_sql.join("\n")}"
  end
end
