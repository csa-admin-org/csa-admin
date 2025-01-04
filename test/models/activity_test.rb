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
    assert activity.errors[:participants_limit].empty?
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

  test "creates an activity without preset" do
    activity = Activity.new(
      date: "2018-03-24",
      start_time: "8:30",
      end_time: "12:00",
      place: "Thielle",
      place_url: "https://goo.gl/maps/xSxmiYRhKWH2",
      title: "Aide aux champs",
      participants_limit: 3,
      description: "Venez nombreux!")

    assert_nil activity.preset_id
    assert_equal "Thielle", activity.places["en"]

    activity.save!

    assert_equal Tod::TimeOfDay.parse("8:30"), activity.start_time
    assert_equal Tod::TimeOfDay.parse("12:00"), activity.end_time
  end

  test "creates an activity with preset" do
    preset = activity_presets(:harvest)
    activity = Activity.new(
      date: "2018-03-24",
      start_time: "8:30",
      end_time: "12:00",
      preset_id: preset.id)

    assert activity.preset_id.present?
    assert_equal "preset", activity.places["en"]
    assert_equal "preset", activity.place_urls["en"]
    assert_equal "preset", activity.titles["en"]

    activity.save!

    h = Activity.find(activity.id)
    assert_equal preset.place, h.place
    assert_equal preset.place_url, h.place_url
    assert_equal preset.title, h.title
  end

  test "does not pad hours in period" do
    activity = Activity.new(
      date: "2018-03-24",
      start_time: "8:30",
      end_time: "12:00")

    assert_equal "8:30-12:00", activity.period
  end
end
