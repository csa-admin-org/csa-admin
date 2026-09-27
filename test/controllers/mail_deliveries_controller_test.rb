# frozen_string_literal: true

require "test_helper"

class MailDeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    login admins(:super)
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "newsletter index member filter lists distinct members for that newsletter" do
    newsletter = newsletters(:sent)
    jane = members(:jane)
    insert_newsletter_deliveries(newsletter, [ jane ], 1)

    get mail_deliveries_path(newsletter_id: newsletter.id)

    assert_response :success
    assert_select "td a", text: members(:john).name
    assert_select "td a", text: jane.name
    assert_select "select[name='q[member_id_eq]'] option[value=?]", members(:john).id
    assert_select "select[name='q[member_id_eq]'] option[value=?]", jane.id
    assert_select "select[name='q[member_id_eq]'] option[value=?]", members(:bob).id, count: 0
  end

  test "newsletter index sidebar member_id pluck stays lean as deliveries grow" do
    newsletter = newsletters(:sent)
    members = [ members(:john), members(:jane) ]
    insert_newsletter_deliveries(newsletter, members, 8)

    few_queries = collect_sql_queries { get mail_deliveries_path(newsletter_id: newsletter.id) }
    assert_response :success
    assert_lean_sidebar_member_plucks few_queries

    insert_newsletter_deliveries(newsletter, members, 25, start_at: 2.hours.ago)
    many_queries = collect_sql_queries { get mail_deliveries_path(newsletter_id: newsletter.id) }
    assert_response :success
    assert_lean_sidebar_member_plucks many_queries

    assert_equal member_id_distinct_plucks(few_queries).size, member_id_distinct_plucks(many_queries).size
    assert_equal member_id_pluck_signatures(few_queries), member_id_pluck_signatures(many_queries)
  end

  test "mailable index member filter uses the same lean member_id pluck" do
    invoice = invoices(:annual_fee)
    MailDelivery.create!(
      mailable_type: "Invoice",
      mailable_ids: [ invoice.id ],
      action: "created",
      member: invoice.member,
      state: :delivered,
      subject: "Invoice created")

    queries = collect_sql_queries {
      get mail_deliveries_path(mailable_type: "Invoice", mailable_id: invoice.id)
    }

    assert_response :success
    assert_select "select[name='q[member_id_eq]'] option[value=?]", invoice.member_id
    assert_lean_sidebar_member_plucks queries
  end

  private

  def insert_newsletter_deliveries(newsletter, members, count, start_at: Time.current)
    now = start_at
    rows = members.flat_map { |member|
      count.times.map { |index|
        {
          mailable_type: "Newsletter",
          mailable_ids: [ newsletter.id ],
          action: "newsletter",
          member_id: member.id,
          subject: "Extra #{member.id} #{index}",
          state: "delivered",
          created_at: now - index.minutes,
          updated_at: now - index.minutes
        }
      }
    }
    existing_ids = MailDelivery.newsletter_id_eq(newsletter.id).pluck(:id)
    MailDelivery.insert_all!(rows)
    deliveries = MailDelivery.newsletter_id_eq(newsletter.id).where(member: members).where.not(id: existing_ids)
    MailDelivery::Email.insert_all!(deliveries.flat_map { |delivery|
      %w[one@doe.com two@doe.com].map { |email|
        {
          mail_delivery_id: delivery.id,
          email: "#{delivery.id}-#{email}",
          state: "delivered",
          created_at: delivery.created_at,
          updated_at: delivery.updated_at,
          email_suppression_ids: [],
          email_suppression_reasons: []
        }
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

  def member_id_distinct_plucks(queries)
    queries.select { |sql|
      sql.match?(/DISTINCT/i) && sql.match?(/["`]mail_deliveries["`]\.["`]member_id["`]/i)
    }
  end

  def member_id_pluck_signatures(queries)
    member_id_distinct_plucks(queries).map { |sql| sql.gsub(/\d+/, "N") }
  end

  def assert_lean_sidebar_member_plucks(queries)
    plucks = member_id_distinct_plucks(queries)
    assert_equal 1, plucks.size, "expected one DISTINCT member_id pluck, got:\n#{queries.join("\n")}"
    sql = plucks.first
    assert_no_match(/JOIN ["`]members["`]/i, sql)
    assert_no_match(/members_mail_deliveries/i, sql)
    assert_no_match(/mail_delivery_emails/i, sql)
    assert_no_match(/ORDER BY ["`]mail_deliveries["`]\.["`]created_at["`]/i, sql)
  end
end
