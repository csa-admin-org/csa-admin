# frozen_string_literal: true

require "test_helper"

class Newsletter::SegmentTest < ActiveSupport::TestCase
  test "segment by basket_size" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(basket_size_ids: [ medium_id ])
    assert_equal [ members(:john) ], segment.members

    segment = Newsletter::Segment.create!(basket_size_ids: [ large_id ])
    assert_equal [ members(:anna), members(:jane) ], segment.members

    segment = Newsletter::Segment.create!(basket_size_ids: [ medium_id, large_id ])
    assert_equal [ members(:john), members(:anna), members(:jane) ], segment.members
  end

  test "segment by basket_complement" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(basket_complement_ids: [ bread_id ])
    assert_equal [ members(:jane) ], segment.members

    segment = Newsletter::Segment.create!(basket_complement_ids: [ eggs_id ])
    assert_empty segment.members

    segment = Newsletter::Segment.create!(basket_complement_ids: [ bread_id, eggs_id ])
    assert_equal [ members(:jane) ], segment.members
  end

  test "segment by depot" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(depot_ids: [ farm_id ])
    assert_equal [ members(:john) ], segment.members

    segment = Newsletter::Segment.create!(depot_ids: [ bakery_id ])
    assert_equal [ members(:anna), members(:jane) ], segment.members

    segment = Newsletter::Segment.create!(depot_ids: [ farm_id, bakery_id ])
    assert_equal [ members(:anna), members(:jane), members(:john) ], segment.members
  end

  test "segment by deliveries cycle" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(delivery_cycle_ids: [ mondays_id ])
    assert_equal [ members(:anna), members(:john), members(:bob) ], segment.members

    segment = Newsletter::Segment.create!(delivery_cycle_ids: [ thursdays_id ])
    assert_equal [ members(:jane) ], segment.members

    segment = Newsletter::Segment.create!(delivery_cycle_ids: [ mondays_id, thursdays_id ])
    assert_equal [ members(:jane), members(:anna), members(:john), members(:bob) ], segment.members
  end

  test "segment by coming deliveries in days" do
    travel_to "2024-03-30 +2:00"

    segment = Newsletter::Segment.create!(coming_deliveries_in_days: 2)
    assert_equal [ members(:john), members(:bob), members(:anna) ], segment.members
  end

  test "segment by renewal state" do
    travel_to "2024-01-01"

    memberships(:jane).update_columns(renew: false)
    segment = Newsletter::Segment.create!(renewal_state: "renewal_canceled")
    assert_equal [ members(:jane) ], segment.members

    memberships(:jane).update_columns(renew: true, renewal_opened_at: Time.current)
    segment = Newsletter::Segment.create!(renewal_state: "renewal_opened")
    assert_equal [ members(:jane) ], segment.members

    segment = Newsletter::Segment.create!(renewal_state: nil)
    assert_not_includes [ members(:jane) ], segment.members
  end

  test "segment by first_membership" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(first_membership: false)
    assert_equal [ members(:john) ], segment.members

    segment = Newsletter::Segment.create!(first_membership: true)
    assert_equal [ members(:anna), members(:bob), members(:jane) ], segment.members

    segment = Newsletter::Segment.create!(first_membership: nil)
    assert_equal [ members(:anna), members(:john), members(:bob), members(:jane) ], segment.members
  end

  test "segment by billing_year_division" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(billing_year_division: 1)
    assert_equal [ members(:anna), members(:john), members(:bob) ], segment.members

    segment = Newsletter::Segment.create!(billing_year_division: 4)
    assert_equal [ members(:jane) ], segment.members

    segment = Newsletter::Segment.create!(billing_year_division: nil)
    assert_equal [ members(:anna), members(:john), members(:bob), members(:jane) ], segment.members
  end

  test "segment by membership_ids" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(membership_ids: "#{memberships(:anna).id}, #{memberships(:john).id}")
    assert_equal [ members(:anna), members(:john) ], segment.members

    segment = Newsletter::Segment.create!(membership_ids: "#{memberships(:bob).id}, #{memberships(:bob).id}")
    assert_equal [ members(:bob) ], segment.members

    segment = Newsletter::Segment.create!(membership_ids: "")
    assert_equal [ members(:anna), members(:john), members(:bob), members(:jane) ], segment.members
  end

  test "segment by city" do
    travel_to "2024-01-01"

    members(:john).update!(city: "Zurich")
    members(:anna).update!(city: "Zurich")

    segment = Newsletter::Segment.create!(city: "Zurich")
    assert_equal [ members(:anna), members(:john) ], segment.members

    segment = Newsletter::Segment.create!(city: "City")
    assert_equal [ members(:bob), members(:jane) ], segment.members

    segment = Newsletter::Segment.create!(city: nil)
    assert_equal [ members(:anna), members(:john), members(:bob), members(:jane) ], segment.members
  end

  test "segment by membership_scope defaults to current_or_future" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!
    assert_equal "current_or_future", segment.membership_scope
    assert_equal [ members(:anna), members(:john), members(:bob), members(:jane) ], segment.members
  end

  test "segment by membership_scope current only" do
    travel_to "2024-01-01"

    # Make john's current membership past so he only has a future one (john_future)
    memberships(:john).update_columns(started_on: "2023-07-01", ended_on: "2023-12-30")

    segment = Newsletter::Segment.create!(membership_scope: "current")
    assert_equal [ members(:anna), members(:bob), members(:jane) ], segment.members
  end

  test "segment by membership_scope future only" do
    travel_to "2024-01-01"

    # Make john's current membership past so he only has a future one (john_future)
    memberships(:john).update_columns(started_on: "2023-07-01", ended_on: "2023-12-30")

    segment = Newsletter::Segment.create!(membership_scope: "future")
    assert_equal [ members(:john) ], segment.members
  end

  test "segment by membership_scope current_or_future includes both" do
    travel_to "2024-01-01"

    # Make john's current membership past so he only has a future one (john_future)
    memberships(:john).update_columns(started_on: "2023-07-01", ended_on: "2023-12-30")

    segment = Newsletter::Segment.create!(membership_scope: "current_or_future")
    assert_equal [ members(:anna), members(:bob), members(:jane), members(:john) ], segment.members
  end

  test "segment by basket_complement with membership_scope current" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(membership_scope: "current", basket_complement_ids: [ bread_id ])
    assert_equal [ members(:jane) ], segment.members
  end

  test "segment by basket_complement with membership_scope future" do
    travel_to "2024-01-01"

    segment = Newsletter::Segment.create!(membership_scope: "future", basket_complement_ids: [ bread_id ])
    assert_empty segment.members
  end

  test "segment validates membership_scope inclusion" do
    segment = Newsletter::Segment.new(membership_scope: "invalid")
    assert_not segment.valid?
    assert_includes segment.errors[:membership_scope], I18n.t("errors.messages.inclusion")
  end
end
