# frozen_string_literal: true

require "test_helper"

class ActivityParticipationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    travel_to "2024-09-11"
    login admins(:super)
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "new form uses coming and past activity optgroups" do
    coming = create_activity(date: Date.current + 1.week)

    get new_activity_participation_path

    assert_response :success
    assert_select "select#activity_participation_activity_id" do
      assert_select "optgroup[label=?]", I18n.t("active_admin.scopes.coming") do
        assert_select "option[value=?]", coming.id
      end
      assert_select "optgroup[label=?]", I18n.t("active_admin.scopes.past") do
        assert_select "option[value=?]", activities(:harvest).id
      end
    end
  end

  test "edit form keeps the assigned activity selected" do
    participation = activity_participations(:john_harvest)

    get edit_activity_participation_path(participation)

    assert_response :success
    assert_select "select#activity_participation_activity_id option[value=?][selected]",
      participation.activity_id
  end

  test "edit form keeps an assigned activity that is older than the collection limit" do
    extras = insert_admin_form_activities!(
      (0...(Activity::ADMIN_FORM_COLLECTION_LIMIT + 5)).map { |i| Date.new(2019, 1, 1) + i.days })
    oldest = extras.min_by(&:date)
    dropped = extras.sort_by(&:date)[1]
    participation = ActivityParticipation.create!(
      member: members(:martha),
      activity: oldest,
      participants_count: 1)

    get edit_activity_participation_path(participation)

    assert_response :success
    assert_select "select#activity_participation_activity_id option[value=?][selected]", oldest.id
    assert_select "select#activity_participation_activity_id option[value=?]", dropped.id, count: 0
  end

  test "new and edit form activity queries stay bounded as activity count grows" do
    participation = activity_participations(:john_harvest)
    insert_admin_form_activities!(
      (0...Activity::ADMIN_FORM_COLLECTION_LIMIT).map { |i| Date.new(2020, 1, 1) + i.days })

    few_new = collect_sql_queries { get new_activity_participation_path }
    assert_response :success
    assert_bounded_activity_form_queries(few_new)

    few_edit = collect_sql_queries { get edit_activity_participation_path(participation) }
    assert_response :success
    assert_bounded_activity_form_queries(few_edit)

    insert_admin_form_activities!(
      (0...Activity::ADMIN_FORM_COLLECTION_LIMIT).map { |i| Date.new(2018, 1, 1) + i.days })

    many_new = collect_sql_queries { get new_activity_participation_path }
    assert_response :success
    assert_bounded_activity_form_queries(many_new)

    many_edit = collect_sql_queries { get edit_activity_participation_path(participation) }
    assert_response :success
    assert_bounded_activity_form_queries(many_edit)

    assert_equal activity_form_load_signatures(few_new), activity_form_load_signatures(many_new)
    assert_equal activity_form_load_signatures(few_edit), activity_form_load_signatures(many_edit)
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

  def activity_collection_loads(queries)
    queries.select { |sql|
      sql.match?(/SELECT .+FROM ["`]activities["`]/i) &&
        sql.match?(/["`]activities["`]\.["`]date["`]/) &&
        !sql.match?(/SELECT 1 AS one/i) &&
        !sql.match?(/COUNT\(/i)
    }
  end

  def activity_form_load_signatures(queries)
    activity_collection_loads(queries).map { |sql| sql.gsub(/\d+/, "N") }
  end

  def assert_bounded_activity_form_queries(queries)
    loads = activity_collection_loads(queries)
    assert_equal 2, loads.size, "expected coming and past Activity collection loads, got:\n#{loads.join("\n")}"
    loads.each do |sql|
      assert_match(/LIMIT/i, sql)
      assert_no_match(/\bSELECT\s+(?:["`]?\w+["`]?\.)?\*/i, sql)
      assert_match(/["`]date["`]/, sql)
      assert_match(/["`]places["`]/, sql)
      assert_no_match(/["`]descriptions["`]/, sql)
      assert_no_match(/["`]titles["`]/, sql)
      assert_no_match(/["`]place_urls["`]/, sql)
    end
  end
end
