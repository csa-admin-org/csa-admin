# frozen_string_literal: true

require "test_helper"
require "shared/bulk_dates_insert"

class ActivityTest < ActiveSupport::TestCase
  include Shared::BulkDatesInsert

  def setup
    @model ||= Activity.new(
      start_time: "8:30",
      end_time: "12:00",
      preset_id: activity_presets(:harvest).id)
  end

  test "validates title presence" do
    activity = Activity.new(title_en: "")
    activity.validate
    assert_not activity.errors[:title_en].empty?
  end

  test "validates participants_limit to be at least 1" do
    activity = Activity.new(participants_limit: 0)
    activity.validate
    assert_not activity.errors[:participants_limit].empty?

    activity = Activity.new(participants_limit: nil)
    activity.validate
    assert_empty activity.errors[:participants_limit]
  end

  test "validates that end_time is greater than start_time" do
    activity = Activity.new(start_time: "11:00", end_time: "10:00")
    activity.validate
    assert_not activity.errors[:end_time].empty?
  end

  test "validates that period is one hour when activity_i18n_scope is hour_work" do
    org(activity_i18n_scope: "hour_work")

    activity = Activity.new(start_time: "10:00", end_time: "11:01")
    activity.validate
    assert_not activity.errors[:end_time].empty?
  end

  test "does not pad hours in period" do
    activity = Activity.new(
      date: "2018-03-24",
      start_time: "8:30",
      end_time: "12:00")

    assert_equal "8:30-12:00", activity.period
  end

  test "admin_form_collection limits past and coming activities and keeps the selected one" do
    travel_to "2024-09-11"
    overflow = Activity::ADMIN_FORM_COLLECTION_LIMIT + 2
    extras = insert_admin_form_activities!(
      (0...overflow).map { |i| Date.new(2019, 1, 1) + i.days } +
      (1..overflow).map { |i| Date.current + i.days })
    oldest = extras.min_by(&:date)
    dropped_past = extras.sort_by(&:date).second
    nearest_coming = extras.select { |activity| activity.date.future? }.min_by(&:date)
    farthest_coming = extras.max_by(&:date)

    collection = Activity.admin_form_collection(selected: oldest)

    assert_equal Activity::ADMIN_FORM_COLLECTION_LIMIT, collection[:coming].size
    assert_equal Activity::ADMIN_FORM_COLLECTION_LIMIT + 1, collection[:past].size
    assert_includes collection[:past].map(&:id), oldest.id
    assert_not_includes collection[:past].map(&:id), dropped_past.id
    assert_includes collection[:coming].map(&:id), nearest_coming.id
    assert_not_includes collection[:coming].map(&:id), farthest_coming.id
  end

  test "admin_form_collection queries are column-narrowed and limited" do
    travel_to "2024-09-11"
    insert_admin_form_activities!((0..5).map { |i| Date.current - (i + 1).weeks })

    queries = []
    callback = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      Activity.admin_form_collection
    end

    collection_loads = queries.select { |sql|
      sql.match?(/FROM ["`]activities["`]/i) && sql.match?(/["`]date["`]/)
    }
    assert_equal 2, collection_loads.size
    collection_loads.each do |sql|
      assert_match(/LIMIT/i, sql)
      assert_no_match(/\bSELECT\s+(?:["`]?\w+["`]?\.)?\*/i, sql)
      assert_match(/["`]places["`]/, sql)
      assert_no_match(/["`]descriptions["`]/, sql)
      assert_no_match(/["`]titles["`]/, sql)
      assert_no_match(/["`]place_urls["`]/, sql)
    end
  end
end
