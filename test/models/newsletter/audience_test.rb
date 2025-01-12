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
    assert_equal [ ], segment.members

    segment = segment_for("depot_id::#{farm_id}")
    assert_equal [ members(:john) ], segment.members
    segment = segment_for("depot_id::#{bakery_id}")
    assert_equal [ members(:anna), members(:jane) ], segment.members
  end

  test "delivery ignore absent or empty baskets" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)

    segment = segment_for("delivery_id::#{delivery.gid}")
    assert_equal [ members(:john), members(:bob), members(:anna) ], segment.members

    memberships(:john).baskets.update_all(state: "absent")
    segment = segment_for("delivery_id::#{delivery.gid}")
    assert_equal [ members(:bob), members(:anna) ], segment.members

    memberships(:bob).baskets.update_all(quantity: 0)
    segment = segment_for("delivery_id::#{delivery.gid}")
    assert_equal [ members(:anna) ], segment.members
  end
end
