# frozen_string_literal: true

require "test_helper"

class Newsletter::AudienceTest < ActiveSupport::TestCase
  test "encrypt and decrypt email" do
    email = "info@csa-admin.org"
    encrypted = Newsletter::Audience.encrypt_email(email)
    assert_equal email, Newsletter::Audience.decrypt_email(encrypted)
  end

  test "decrypt email with invalid token" do
    assert_nil Newsletter::Audience.decrypt_email("invalid")
  end

  def segment_for(audience)
    Newsletter::Audience::Segment.parse(audience)
  end

  test "segment#name" do
    segment = segment_for("depot_id::#{farm_id}")
    assert_equal "Farm", segment.name

    segment = segment_for("depot_id::999")
    assert_equal "Unknown", segment.name
  end

  test "member_state" do
    waiting = members(:aria)
    active1 = members(:john)
    active2 = members(:jane)
    support = members(:martha)
    inactive = members(:mary)

    segment = segment_for("member_state::all")
    assert_equal [ inactive, support, active1, active2, waiting ], segment.members

    segment = segment_for("member_state::not_inactive")
    assert_equal [ support, active1, active2, waiting ], segment.members

    segment = segment_for("member_state::waiting")
    assert_equal [ waiting ], segment.members

    segment = segment_for("member_state::active")
    assert_equal [ active1, active2 ], segment.members

    segment = segment_for("member_state::support")
    assert_equal [ support ], segment.members

    segment = segment_for("member_state::inactive")
    assert_equal [ inactive ], segment.members
  end

  test "membership_state" do
    travel_to "2023-01-01"
    segment = segment_for("membership_state::ongoing")
    assert_equal [ members(:john) ], segment.members.to_a
    segment = segment_for("membership_state::trial")
    assert_empty segment.members
    segment = segment_for("membership_state::future")
    assert_equal 4, segment.members.size
    assert_includes segment.members, members(:anna)
    assert_includes segment.members, members(:john)
    assert_includes segment.members, members(:bob)
    assert_includes segment.members, members(:jane)
    segment = segment_for("membership_state::past")
    assert_empty segment.members

    travel_to "2024-01-01"
    segment = segment_for("membership_state::ongoing")
    assert_equal 2, segment.members.size
    assert_includes segment.members, members(:john)
    assert_includes segment.members, members(:jane)
    segment = segment_for("membership_state::trial")
    assert_equal 2, segment.members.size
    assert_includes segment.members, members(:anna)
    assert_includes segment.members, members(:bob)
    segment = segment_for("membership_state::future")
    assert_equal [ members(:john) ], segment.members.to_a
    segment = segment_for("membership_state::past")
    assert_equal [ members(:john) ], segment.members.to_a

    travel_to "2025-01-01"
    segment = segment_for("membership_state::ongoing")
    assert_equal [ members(:john) ], segment.members.to_a
    segment = segment_for("membership_state::trial")
    assert_empty segment.members
    segment = segment_for("membership_state::future")
    assert_empty segment.members
    segment = segment_for("membership_state::past")
    assert_equal 4, segment.members.size
    assert_includes segment.members, members(:john)
    assert_includes segment.members, members(:anna)
    assert_includes segment.members, members(:bob)
    assert_includes segment.members, members(:jane)
  end

  test "activity_state" do
    travel_to "2024-01-01"

    assert_equal 2, memberships(:john).activity_participations_demanded_annually
    assert_equal 0, memberships(:john).activity_participations_missing
    assert_equal 2, memberships(:jane).activity_participations_demanded_annually
    assert_equal 2, memberships(:jane).activity_participations_missing

    segment = segment_for("activity_state::demanded")
    assert_equal [ members(:john), members(:jane) ], segment.members

    segment = segment_for("activity_state::missing")
    assert_equal [ members(:jane) ], segment.members
  end

  test "memberships" do
    travel_to "2024-01-01"

    segment = segment_for("basket_size_id::#{medium_id}")
    assert_equal [ members(:john) ], segment.members
    segment = segment_for("basket_size_id::#{large_id}")
    assert_equal [ members(:anna), members(:jane) ], segment.members

    segment = segment_for("basket_complement_id::#{bread_id}")
    assert_equal [ members(:jane) ], segment.members
    segment = segment_for("basket_complement_id::#{eggs_id}")
    assert_empty segment.members

    segment = segment_for("depot_id::#{farm_id}")
    assert_equal [ members(:john) ], segment.members
    segment = segment_for("depot_id::#{bakery_id}")
    assert_equal [ members(:anna), members(:jane) ], segment.members
  end

  test "delivery ignore absent or empty baskets" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)

    segment = segment_for("delivery_id::#{delivery.gid}")
    assert_equal 3, segment.members.size
    assert_includes segment.members, members(:john)
    assert_includes segment.members, members(:bob)
    assert_includes segment.members, members(:anna)

    memberships(:john).baskets.update_all(state: "absent")
    segment = segment_for("delivery_id::#{delivery.gid}")
    assert_equal 2, segment.members.size
    assert_includes segment.members, members(:bob)
    assert_includes segment.members, members(:anna)

    memberships(:bob).baskets.update_all(quantity: 0)
    segment = segment_for("delivery_id::#{delivery.gid}")
    assert_equal [ members(:anna) ], segment.members.to_a
  end

  test "bidding_round_pledge_presence" do
    travel_to "2024-01-01"
    BiddingRound::Pledge.create!(
      bidding_round: bidding_rounds(:open_2024),
      membership: memberships(:jane),
      basket_size_price: 31)

    segment = segment_for("bidding_round_pledge_presence::true")
    assert_equal [ members(:jane) ], segment.members
    segment = segment_for("bidding_round_pledge_presence::false")
    assert_equal [ members(:anna), members(:john), members(:bob) ], segment.members

    bidding_rounds(:open_2024).fail!
    segment = segment_for("bidding_round_pledge_presence::true")
    assert_empty segment.members
    segment = segment_for("bidding_round_pledge_presence::false")
    assert_empty segment.members
  end

  test "excludes discarded members from audience" do
    travel_to "2024-01-01"

    segment = segment_for("member_state::active")
    assert_includes segment.members, members(:john)

    members(:john).update_columns(discarded_at: Time.current)

    segment = segment_for("member_state::active")
    assert_not_includes segment.members, members(:john)
  end
end
