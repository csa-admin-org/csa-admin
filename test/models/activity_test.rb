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
end
