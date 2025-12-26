# frozen_string_literal: true

require "test_helper"

class Member::StateTransitionsTest < ActiveSupport::TestCase
  test "validate! sets state to waiting if waiting basket/depot" do
    admin = admins(:super)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)
    assert_changes -> { member.state }, from: "pending", to: "waiting" do
      member.validate!(admin)
    end
    assert member.validated_at.present?
    assert_equal admin, member.validator
  end

  test "validate! sets state to active if shop depot is set" do
    admin = admins(:super)
    member = members(:aria)
    member.update!(
      state: "pending",
      validated_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      shop_depot: depots(:farm))
    assert_changes -> { member.state }, from: "pending", to: "active" do
      member.validate!(admin)
    end
    assert member.validated_at.present?
    assert_equal admin, member.validator
  end

  test "validate! sets state to support if annual_fee is present" do
    admin = admins(:super)
    member = members(:aria)
    member.update!(
      state: "pending",
      validated_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      annual_fee: 30)
    assert_changes -> { member.state }, from: "pending", to: "support" do
      member.validate!(admin)
    end
    assert member.validated_at.present?
    assert_equal admin, member.validator
  end

  test "validate! sets state to inactive if annual_fee is not present" do
    admin = admins(:super)
    member = members(:aria)
    member.update!(
      state: "pending",
      validated_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      annual_fee: nil)
    assert_changes -> { member.state }, from: "pending", to: "inactive" do
      member.validate!(admin)
    end
    assert member.validated_at.present?
    assert_equal admin, member.validator
  end

  test "validate! sets state to support if desired_shares_number is present" do
    org(annual_fee: nil, share_price: 100, shares_number: 1)
    admin = admins(:super)
    member = members(:aria)
    member.update!(
      state: "pending",
      validated_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      desired_shares_number: 30)
    assert_changes -> { member.state }, from: "pending", to: "support" do
      member.validate!(admin)
    end
    assert member.validated_at.present?
    assert_equal admin, member.validator
  end

  test "validate! raises if not pending" do
    admin = admins(:super)
    member = members(:john)
    assert_raises(InvalidTransitionError) { member.validate!(admin) }
  end

  test "wait! sets state to waiting and reset waiting_started_at" do
    member = members(:martha)
    member.update(waiting_started_at: 1.month.ago, annual_fee: 42)
    assert_changes -> { member.state }, from: "support", to: "waiting" do
      member.wait!
    end
    assert member.waiting_started_at > 1.minute.ago
    assert_equal 42, member.annual_fee
  end

  test "wait! sets state to waiting and set default annual_fee" do
    member = members(:mary)
    assert_changes -> { member.state }, from: "inactive", to: "waiting" do
      member.wait!
    end
    assert member.waiting_started_at > 1.minute.ago
    assert_equal 30, member.annual_fee
  end

  test "wait! sets state to waiting and clear annual_fee when annual_fee_support_member_only is true" do
    org(annual_fee_support_member_only: true)
    member = members(:mary)
    assert_changes -> { member.state }, from: "inactive", to: "waiting" do
      member.wait!
    end
    assert member.waiting_started_at > 1.minute.ago
    assert_nil member.annual_fee
  end

  test "wait! raises if not support or inactive" do
    member = members(:john)
    assert_raises(InvalidTransitionError) { member.wait! }
  end

  test "review_active_state! activates new active member" do
    member = members(:john)
    member.update_column(:state, "inactive")

    travel_to "2023-01-01"
    assert_changes -> { member.state }, from: "inactive", to: "active" do
      member.review_active_state!
    end
  end

  test "review_active_state! activates new inactive member with shop_depot" do
    member = members(:mary)
    member.update_column(:shop_depot_id, depots(:farm).id)
    assert_changes -> { member.state }, from: "inactive", to: "active" do
      member.review_active_state!
    end
  end

  test "review_active_state! deactivates old active member" do
    member = members(:john)
    travel_to "2026-01-01"
    assert_changes -> { member.state }, from: "active", to: "inactive" do
      member.review_active_state!
    end
  end

  test "review_active_state! sets state to support when membership.renewal_annual_fee is present" do
    member = members(:john)
    memberships(:john_future).cancel!(renewal_annual_fee: "1")
    travel_to "2026-01-01"
    assert_changes -> { member.state }, from: "active", to: "support" do
      member.review_active_state!
    end
    assert_equal 30, member.annual_fee
  end

  test "review_active_state! sets state to support when user still has shares" do
    org(share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:john)
    member.update_columns(existing_shares_number: 1)
    assert_equal 1, member.shares_number

    travel_to "2026-01-01"
    assert_changes -> { member.state }, from: "active", to: "support" do
      member.review_active_state!
    end
  end

  test "review_active_state! sets state to inactive and desired_shares_number to 0 when membership ended" do
    org(share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:john)
    member.update_columns(desired_shares_number: 1)

    travel_to "2026-01-01"
    assert_changes -> { member.state }, from: "active", to: "inactive" do
      member.review_active_state!
    end
    assert_equal 0, member.desired_shares_number
    assert_nil member.annual_fee
    assert_equal 0, member.shares_number
  end

  test "activate! activates new active member and sent member-activated email" do
    mail_templates(:member_activated).update!(active: true)
    member = members(:john)
    member.update_columns(state: "inactive", activated_at: nil, annual_fee: nil)

    assert_difference "MemberMailer.deliveries.size" do
      perform_enqueued_jobs { member.activate! }
    end

    assert_equal 30, member.annual_fee
    assert member.activated_at?
    mail = MemberMailer.deliveries.last
    assert_equal "Welcome!", mail.subject
  end

  test "activate! when annual_fee_support_member_only is true" do
    org(annual_fee_support_member_only: true)
    member = members(:john)
    member.update_columns(state: "inactive", activated_at: nil, annual_fee: nil)

    assert_no_changes -> { member.reload.annual_fee } do
      perform_enqueued_jobs { member.activate! }
    end

    assert member.activated_at?
  end

  test "activate! activates previously active member" do
    mail_templates(:member_activated).update!(active: true)
    member = members(:john)
    member.update_columns(state: "inactive", activated_at: 1.year.ago)

    assert_difference "MemberMailer.deliveries.size" do
      perform_enqueued_jobs { member.activate! }
    end

    assert member.activated_at?
    mail = MemberMailer.deliveries.last
    assert_equal "Welcome!", mail.subject
  end

  test "activate! previously active member (recent)" do
    mail_templates(:member_activated).update!(active: true)
    member = members(:john)
    member.update_columns(state: "inactive", activated_at: 1.day.ago)

    assert_no_difference "MemberMailer.deliveries.size" do
      perform_enqueued_jobs { member.activate! }
    end

    assert member.activated_at?
  end

  test "deactivate! sets state to inactive and clears waiting_started_at, annual_fee, and shop_depot" do
    member = members(:martha)
    member.update(shop_depot: depots(:farm))

    assert_changes -> { member.state }, from: "active", to: "inactive" do
      member.deactivate!
    end
    assert_nil member.waiting_started_at
    assert_nil member.annual_fee
    assert_nil member.shop_depot
  end

  test "deactivate! sets state to inactive and clears annual_fee" do
    member = members(:martha)

    assert_changes -> { member.state }, from: "support", to: "inactive" do
      member.deactivate!
    end
    assert_nil member.annual_fee
  end

  test "deactivate! sets state to inactive when membership ended" do
    member = members(:john)
    travel_to "2026-01-01"
    assert_changes -> { member.state }, from: "active", to: "inactive" do
      member.deactivate!
    end
    assert_nil member.annual_fee
  end

  test "deactivate! raises if current membership" do
    member = members(:john)
    assert_raises(InvalidTransitionError) { member.deactivate! }
  end

  test "deactivate! support member with shares" do
    org(share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:martha)
    member.update!(existing_shares_number: 2)
    assert_changes -> { member.state }, from: "support", to: "inactive" do
      member.deactivate!
    end
    assert_equal 0, member.desired_shares_number
    assert_equal(-2, member.required_shares_number)
  end

  test "deactivate! support member with only desired shares" do
    org(share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:martha)
    member.update!(desired_shares_number: 2)
    assert_changes -> { member.state }, from: "support", to: "inactive" do
      member.deactivate!
    end
    assert_equal 0, member.desired_shares_number
    assert_equal 0, member.required_shares_number
  end

  test "can_wait? returns true for support member" do
    member = members(:martha)
    assert member.can_wait?
  end

  test "can_wait? returns true for inactive member" do
    member = members(:mary)
    assert member.can_wait?
  end

  test "can_wait? returns false for active member" do
    travel_to "2024-01-01"
    member = members(:john)
    assert_not member.can_wait?
  end

  test "can_deactivate? returns true for waiting member" do
    member = members(:aria)
    assert member.can_deactivate?
  end

  test "can_deactivate? returns true for support member" do
    member = members(:martha)
    assert member.can_deactivate?
  end

  test "can_deactivate? returns false for inactive member" do
    member = members(:mary)
    assert_not member.can_deactivate?
  end
end
