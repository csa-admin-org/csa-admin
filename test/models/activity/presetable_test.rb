# frozen_string_literal: true

require "test_helper"

class Activity::PresetableTest < ActiveSupport::TestCase
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

  test "preset returns the ActivityPreset when set" do
    preset = activity_presets(:harvest)
    activity = Activity.new(preset_id: preset.id)

    assert_equal preset, activity.preset
  end

  test "preset returns nil when not set" do
    activity = Activity.new

    assert_nil activity.preset
  end
end
