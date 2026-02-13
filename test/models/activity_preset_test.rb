# frozen_string_literal: true

require "test_helper"

class ActivityPresetTest < ActiveSupport::TestCase
  test "validates uniqueness of places scoped to titles" do
    existing = activity_presets(:harvest)
    duplicate = ActivityPreset.new(
      places: existing.places,
      titles: existing.titles
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:places], "has already been taken"
  end

  test "allows same place with different title" do
    existing = activity_presets(:harvest)
    preset = ActivityPreset.new(
      places: existing.places,
      titles: { "en" => "Different title" }
    )

    assert_not_includes preset.errors[:places], "has already been taken"
  end

  test "allows same title with different place" do
    existing = activity_presets(:harvest)
    preset = ActivityPreset.new(
      places: { "en" => "Different place" },
      titles: existing.titles
    )

    assert_not_includes preset.errors[:places], "has already been taken"
  end
end
