# frozen_string_literal: true

require "test_helper"

class ActivityParticipation::CarpoolingTest < ActiveSupport::TestCase
  test "validates carpooling phone and city presence when carpooling is checked" do
    participation = ActivityParticipation.build(
      activity: activities(:harvest),
      participants_count: 1,
      carpooling: "1")
    participation.validate

    assert_not participation.errors[:carpooling_phone].empty?
    assert_not participation.errors[:carpooling_city].empty?
  end

  test "validates carpooling phone format when carpooling is checked" do
    travel_to "2024-01-01"
    participation = ActivityParticipation.build(
      activity: activities(:harvest),
      participants_count: 1,
      carpooling_phone: "foo",
      carpooling: "1")
    participation.validate

    assert_not participation.errors[:carpooling_phone].empty?
  end

  test "validates carpooling phone accepts any valid international number" do
    travel_to "2024-01-01"

    participation = ActivityParticipation.build(
      activity: activities(:harvest),
      participants_count: 1,
      carpooling_phone: "+49 30 123456",
      carpooling_city: "Berlin",
      carpooling: "1")
    participation.validate

    assert_empty participation.errors[:carpooling_phone]
  end

  test "resets carpooling phone and city if carpooling = 0" do
    participation = ActivityParticipation.create!(
      member: members(:martha),
      activity: activities(:harvest),
      carpooling: "0",
      carpooling_phone: "+41 79 123 45 67",
      carpooling_city: "Nowhere")

    assert_nil participation.carpooling_phone
    assert_nil participation.carpooling_city
  end

  test "carpooling? returns true when carpooling phone is present" do
    participation = ActivityParticipation.new(carpooling_phone: "+41 79 123 45 67")
    assert participation.carpooling?
  end

  test "carpooling? returns false when carpooling phone is blank" do
    participation = ActivityParticipation.new(carpooling_phone: nil)
    assert_not participation.carpooling?
  end
end
