# frozen_string_literal: true

require "test_helper"

class Member::StateTransitionsTest < ActiveSupport::TestCase
  def member_mail_delivery_count(action)
    MailDelivery.where(mailable_type: "Member", action: action).count
  end

  test "validate! sets state to waiting if waiting basket/depot" do
    admin = admins(:super)
    mail_templates(:member_validated).update!(active: true)
    mail_templates(:member_activated).update!(active: true)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)

    assert_difference -> { member_mail_delivery_count("validated") }, 1 do
      assert_no_difference -> { member_mail_delivery_count("activated") } do
        assert_changes -> { member.state }, from: "pending", to: "waiting" do
          member.validate!(admin)
        end
      end
    end
    assert member.validated_at.present?
    assert_equal admin, member.validator
  end

  test "validate! sets default annual fee when pending member moves to waiting list" do
    admin = admins(:super)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil, annual_fee: nil)

    member.validate!(admin)

    assert member.reload.waiting?
    assert_equal 30, member.annual_fee
  end

  test "validate! clears annual fee when pending member moves to waiting list for support-only fees" do
    org(annual_fee_support_member_only: true)
    admin = admins(:super)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil, annual_fee: 30)

    member.validate!(admin)

    assert member.reload.waiting?
    assert_nil member.annual_fee
  end

  test "validate! creates membership directly when waiting membership start date is set" do
    travel_to "2024-05-01"
    admin = admins(:super)
    mail_templates(:member_validated).update!(active: true)
    mail_templates(:member_activated).update!(active: true)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)
    existing_audit_ids = member.audits.pluck(:id)
    member.waiting_membership_started_on = Date.new(2024, 5, 6)
    validated_membership = nil

    assert_difference -> { member_mail_delivery_count("activated") }, 1 do
      assert_no_difference -> { member_mail_delivery_count("validated") } do
        assert_difference "Membership.count", 1 do
          validated_membership = member.validate!(admin)
        end
      end
    end

    assert_nil member.waiting_membership_started_on

    membership = member.reload.memberships.order(:id).last
    assert_equal membership, validated_membership
    assert member.active?
    assert_equal Date.new(2024, 5, 6), membership.started_on
    assert_nil member.waiting_started_at
    assert_nil member.waiting_basket_size_id
    assert_nil member.waiting_depot_id
    assert_nil member.waiting_delivery_cycle_id

    state_changes = member.audits.where.not(id: existing_audit_ids).filter_map { |audit|
      audit.audited_changes["state"]
    }
    refute_includes state_changes, [ "pending", "waiting" ]
  end

  test "validate! creates membership directly when waiting list is disabled" do
    travel_to "2024-05-01"
    org(features: Current.org.features - [ :waiting_list ])
    admin = admins(:super)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)
    member.waiting_membership_started_on = Date.new(2024, 5, 13)

    assert_difference "Membership.count", 1 do
      member.validate!(admin)
    end

    membership = member.reload.memberships.order(:id).last
    assert member.active?
    assert_equal Date.new(2024, 5, 13), membership.started_on
  end

  test "validate! creates membership from selected delivery cycle when waiting list is disabled" do
    travel_to "2024-05-01"
    org(features: Current.org.features - [ :waiting_list ])
    admin = admins(:super)
    mail_templates(:member_validated).update!(active: true)
    mail_templates(:member_activated).update!(active: true)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)

    assert_difference -> { member_mail_delivery_count("activated") }, 1 do
      assert_no_difference -> { member_mail_delivery_count("validated") } do
        assert_difference "Membership.count", 1 do
          member.validate!(admin)
        end
      end
    end

    membership = member.reload.memberships.order(:id).last
    assert member.active?
    assert_equal Date.new(2024, 5, 6), membership.started_on
  end

  test "validate! rolls back direct creation when membership request is incomplete" do
    travel_to "2024-05-01"
    org(features: Current.org.features - [ :waiting_list ])
    admin = admins(:super)
    member = members(:aria)
    member.update_columns(
      state: "pending",
      validated_at: nil,
      waiting_depot_id: nil,
      waiting_delivery_cycle_id: nil)

    assert_no_difference "Membership.count" do
      assert_raises(ActiveRecord::RecordInvalid) { member.validate!(admin) }
    end
    assert member.reload.pending?
    assert_nil member.validated_at
  end

  test "validate! rolls back direct creation when selected delivery cycle has no upcoming delivery" do
    travel_to "2026-01-01"
    org(features: Current.org.features - [ :waiting_list ])
    admin = admins(:super)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)

    error = nil
    assert_no_difference "Membership.count" do
      error = assert_raises(ActiveRecord::RecordInvalid) { member.validate!(admin) }
    end
    assert_includes error.record.errors[:waiting_delivery_cycle], "has no upcoming delivery"
    assert member.reload.pending?
    assert_nil member.validated_at
  end

  test "validate! sets state to active if shop depot is set" do
    org(features: Current.org.features | [ :shop ])
    admin = admins(:super)
    mail_templates(:member_validated).update!(active: true)
    mail_templates(:member_shop_depot_activated).update!(active: true)
    member = members(:aria)
    member.update!(
      state: "pending",
      validated_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      waiting_delivery_cycle: nil,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: nil,
      shop_depot: depots(:farm))

    assert_difference -> { member_mail_delivery_count("shop_depot_activated") }, 1 do
      assert_no_difference -> { member_mail_delivery_count("validated") } do
        assert_changes -> { member.state }, from: "pending", to: "active" do
          member.validate!(admin)
        end
      end
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
      waiting_delivery_cycle: nil,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: nil,
      annual_fee: 30)
    assert_changes -> { member.state }, from: "pending", to: "support" do
      member.validate!(admin)
    end
    assert member.validated_at.present?
    assert_equal admin, member.validator
  end

  test "validate! sets state to support for support-only registration" do
    admin = admins(:super)
    member = members(:aria)
    member.update!(
      state: "pending",
      validated_at: nil,
      waiting_basket_size_id: 0,
      waiting_depot: nil,
      waiting_delivery_cycle: nil,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: nil,
      annual_fee: 30)

    mail_templates(:member_validated).update!(active: true)
    mail_templates(:member_activated).update!(active: true)

    assert_not member.membership_request?
    assert_difference -> { member_mail_delivery_count("validated") }, 1 do
      assert_no_difference -> { member_mail_delivery_count("activated") } do
        assert_no_difference "Membership.count" do
          assert_changes -> { member.state }, from: "pending", to: "support" do
            member.validate!(admin)
          end
        end
      end
    end
    assert_nil member.reload.waiting_basket_size_id
    assert member.validated_at.present?
    assert_equal admin, member.validator
  end

  test "validate! sets state to support if annual_fee is zero" do
    admin = admins(:super)
    member = members(:aria)
    member.update!(
      state: "pending",
      validated_at: nil,
      waiting_basket_size: nil,
      waiting_depot: nil,
      waiting_delivery_cycle: nil,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: nil,
      annual_fee: 0)
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
      waiting_delivery_cycle: nil,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: nil,
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
      waiting_delivery_cycle: nil,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: nil,
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
    org(features: (Current.org.features - [ :annual_fee ]) | [ :shares ], share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:john)
    member.update_columns(existing_shares_number: 1)
    assert_equal 1, member.shares_number

    travel_to "2026-01-01"
    assert_changes -> { member.state }, from: "active", to: "support" do
      member.review_active_state!
    end
  end

  test "review_active_state! sets state to inactive and desired_shares_number to 0 when membership ended" do
    org(features: (Current.org.features - [ :annual_fee ]) | [ :shares ], share_price: 100, shares_number: 1, annual_fee: nil)
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
    travel_to "2024-01-01"
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
    travel_to "2024-01-01"
    org(annual_fee_support_member_only: true)
    member = members(:john)
    member.update_columns(state: "inactive", activated_at: nil, annual_fee: nil)

    assert_no_changes -> { member.reload.annual_fee } do
      perform_enqueued_jobs { member.activate! }
    end

    assert member.activated_at?
  end

  test "activate! sends shop-depot-activated email without membership" do
    travel_to "2024-01-01"
    org(features: [ :shop ])
    mail_templates(:member_activated).update!(active: true)
    mail_templates(:member_shop_depot_activated).update!(active: true)
    member = members(:mary)
    member.update_columns(
      shop_depot_id: depots(:farm).id,
      activated_at: nil,
      annual_fee: nil)

    assert_difference "MemberMailer.deliveries.size" do
      perform_enqueued_jobs { member.activate! }
    end

    assert member.activated_at?
    mail = MemberMailer.deliveries.last
    assert_equal "Your shop access is active!", mail.subject
  end

  test "activate! does not send shop-depot-activated email when shop feature is disabled" do
    travel_to "2024-01-01"
    org(features: [])
    mail_templates(:member_shop_depot_activated).update!(active: true)
    member = members(:mary)
    member.update_columns(
      shop_depot_id: depots(:farm).id,
      activated_at: nil,
      annual_fee: nil)

    assert_no_difference "MemberMailer.deliveries.size" do
      perform_enqueued_jobs { member.activate! }
    end

    assert member.activated_at?
  end

  test "activate! activates previously active member" do
    travel_to "2024-01-01"
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
    travel_to "2024-01-01"
    mail_templates(:member_activated).update!(active: true)
    member = members(:john)
    member.update_columns(state: "inactive", activated_at: 1.day.ago)

    assert_no_difference "MemberMailer.deliveries.size" do
      perform_enqueued_jobs { member.activate! }
    end

    assert member.activated_at?
  end

  test "deactivate! sets state to inactive and clears waiting membership attributes, annual_fee, and shop_depot" do
    member = members(:martha)
    member.update!(
      shop_depot: depots(:farm),
      waiting_basket_size: basket_sizes(:small),
      waiting_depot: depots(:farm),
      waiting_delivery_cycle: delivery_cycles(:mondays),
      waiting_basket_price_extra: 1,
      waiting_activity_participations_demanded_annually: 2,
      waiting_billing_year_division: 1,
      waiting_basket_complement_ids: [ bread_id ],
      waiting_alternative_depot_ids: [ depots(:bakery).id ])

    assert_changes -> { member.state }, from: "active", to: "inactive" do
      member.deactivate!
    end
    assert_nil member.waiting_started_at
    assert_nil member.waiting_basket_size_id
    assert_nil member.waiting_depot_id
    assert_nil member.waiting_delivery_cycle_id
    assert_nil member.waiting_basket_price_extra
    assert_nil member.waiting_activity_participations_demanded_annually
    assert_nil member.waiting_billing_year_division
    assert_empty member.waiting_basket_complement_ids
    assert_empty member.waiting_alternative_depot_ids
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
    travel_to "2024-01-01"
    member = members(:john)
    assert_raises(InvalidTransitionError) { member.deactivate! }
  end

  test "deactivate! support member with shares" do
    org(features: (Current.org.features - [ :annual_fee ]) | [ :shares ], share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:martha)
    member.update!(existing_shares_number: 2)
    assert_changes -> { member.state }, from: "support", to: "inactive" do
      member.deactivate!
    end
    assert_equal 0, member.desired_shares_number
    assert_equal(-2, member.required_shares_number)
  end

  test "deactivate! support member with only desired shares" do
    org(features: (Current.org.features - [ :annual_fee ]) | [ :shares ], share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:martha)
    member.update!(desired_shares_number: 2)
    assert_changes -> { member.state }, from: "support", to: "inactive" do
      member.deactivate!
    end
    assert_equal 0, member.desired_shares_number
    assert_equal 0, member.required_shares_number
  end

  test "setting annual_fee to zero on inactive member moves to support" do
    member = members(:mary)
    assert member.inactive?
    member.update!(annual_fee: 0)
    assert member.support?
    assert_equal 0, member.annual_fee
  end

  test "support member with zero annual_fee stays support when editing other fields" do
    member = members(:mary)
    member.update!(annual_fee: 0)
    assert member.support?
    member.update!(note: "updated note")
    assert member.support?
    assert_equal 0, member.annual_fee
  end

  test "deactivate! support member with zero annual_fee" do
    member = members(:mary)
    member.update!(annual_fee: 0)
    assert member.support?
    assert_changes -> { member.state }, from: "support", to: "inactive" do
      member.deactivate!
    end
    assert_nil member.annual_fee
  end

  test "clearing annual_fee on support member with zero fee moves to inactive" do
    member = members(:mary)
    member.update!(annual_fee: 0)
    assert member.support?
    member.update!(annual_fee: nil)
    assert member.inactive?
    assert_nil member.annual_fee
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
