# frozen_string_literal: true

require "test_helper"

class Activity::AvailabilityTest < ActiveSupport::TestCase
  test "full? returns true when participants_count equals participants_limit" do
    activity = activities(:harvest)
    activity.update!(participants_limit: 3)

    assert_equal 3, activity.participants_count
    assert activity.full?
  end

  test "full? returns false when participants_count is below participants_limit" do
    activity = activities(:harvest)
    activity.update!(participants_limit: 5)

    assert_equal 3, activity.participants_count
    assert_not activity.full?
  end

  test "full? returns false when participants_limit is nil" do
    activity = activities(:harvest)
    activity.update!(participants_limit: nil)

    assert_not activity.full?
  end

  test "missing_participants? returns true when there is room" do
    activity = activities(:harvest)
    activity.update!(participants_limit: 5)

    assert activity.missing_participants?
  end

  test "missing_participants? returns true when no limit set" do
    activity = activities(:harvest)
    activity.update!(participants_limit: nil)

    assert activity.missing_participants?
  end

  test "missing_participants? returns false when full" do
    activity = activities(:harvest)
    activity.update!(participants_limit: 3)

    assert_not activity.missing_participants?
  end

  test "participants_count sums all participation participants_count" do
    activity = activities(:harvest)

    assert_equal 3, activity.participants_count
  end

  test "missing_participants_count returns difference between limit and current count" do
    activity = activities(:harvest)
    activity.update!(participants_limit: 5)

    assert_equal 2, activity.missing_participants_count
  end

  test "missing_participants_count returns nil when no limit set" do
    activity = activities(:harvest)
    activity.update!(participants_limit: nil)

    assert_nil activity.missing_participants_count
  end

  test "participant? returns true when member has participation" do
    activity = activities(:harvest)
    member = members(:john)

    assert activity.participant?(member)
  end

  test "participant? returns false when member has no participation" do
    activity = activities(:harvest)
    member = members(:martha)

    assert_not activity.participant?(member)
  end

  test "without_participations scope returns activities with no participations" do
    activity = Activity.create!(
      date: 1.week.from_now,
      start_time: "8:00",
      end_time: "12:00",
      title: "Empty activity",
      place: "Nowhere")

    assert_includes Activity.without_participations, activity
    assert_not_includes Activity.without_participations, activities(:harvest)
  end

  test "visible scope returns only visible activities" do
    visible_activity = Activity.create!(
      date: 1.week.from_now,
      start_time: "8:00",
      end_time: "12:00",
      title: "Visible activity",
      place: "Here",
      visible: true)
    hidden_activity = Activity.create!(
      date: 1.week.from_now,
      start_time: "8:00",
      end_time: "12:00",
      title: "Hidden activity",
      place: "There",
      visible: false)

    assert_includes Activity.visible, visible_activity
    assert_not_includes Activity.visible, hidden_activity
  end

  test "hidden scope returns only hidden activities" do
    visible_activity = Activity.create!(
      date: 1.week.from_now,
      start_time: "8:00",
      end_time: "12:00",
      title: "Visible activity",
      place: "Here",
      visible: true)
    hidden_activity = Activity.create!(
      date: 1.week.from_now,
      start_time: "8:00",
      end_time: "12:00",
      title: "Hidden activity",
      place: "There",
      visible: false)

    assert_includes Activity.hidden, hidden_activity
    assert_not_includes Activity.hidden, visible_activity
  end

  test "available_for excludes hidden activities" do
    member = members(:martha)
    limit = Current.org.activity_availability_limit_in_days.days.from_now

    visible_activity = Activity.create!(
      date: limit + 1.day,
      start_time: "8:00",
      end_time: "12:00",
      title: "Visible activity",
      place: "Here",
      visible: true)
    hidden_activity = Activity.create!(
      date: limit + 1.day,
      start_time: "8:00",
      end_time: "12:00",
      title: "Hidden activity",
      place: "There",
      visible: false)

    available = Activity.available_for(member)

    assert_includes available, visible_activity
    assert_not_includes available, hidden_activity
  end

  test "available excludes hidden activities" do
    limit = Current.org.activity_availability_limit_in_days.days.from_now

    visible_activity = Activity.create!(
      date: limit + 1.day,
      start_time: "8:00",
      end_time: "12:00",
      title: "Visible activity",
      place: "Here",
      visible: true)
    hidden_activity = Activity.create!(
      date: limit + 1.day,
      start_time: "8:00",
      end_time: "12:00",
      title: "Hidden activity",
      place: "There",
      visible: false)

    available = Activity.available

    assert_includes available, visible_activity
    assert_not_includes available, hidden_activity
  end

  test "activity is visible by default" do
    activity = Activity.new

    assert activity.visible
  end
end
