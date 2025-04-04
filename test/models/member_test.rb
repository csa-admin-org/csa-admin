# frozen_string_literal: true

require "test_helper"

class MemberTest < ActiveSupport::TestCase
  test "requires address, city, zip, country_code on creation" do
    member = Member.new(
      address: nil,
      city: nil,
      zip: nil)
    member.country_code = nil

    assert_not member.valid?
    assert_includes member.errors[:address], "can't be blank"
    assert_includes member.errors[:city], "can't be blank"
    assert_includes member.errors[:zip], "can't be blank"
    assert_includes member.errors[:country_code], "can't be blank"
  end

  test "does not require address, city, zip when inactive" do
    member = members(:mary)
    member.update(address: nil, city: nil, zip: nil, country_code: nil)

    assert member.valid?
  end

  test "does require address, city, zip on update" do
    member = members(:john)
    member.update(address: nil, city: nil, zip: nil, country_code: nil)

    assert_not member.valid?
    assert_includes member.errors[:address], "can't be blank"
    assert_includes member.errors[:city], "can't be blank"
    assert_includes member.errors[:zip], "can't be blank"
    assert_includes member.errors[:country_code], "can't be blank"
  end

  test "sets first organization billing_year_divisions by default" do
    Current.org.billing_year_divisions = [ 4, 12 ]
    member = members(:aria)
    member.update(waiting_billing_year_division: nil)

    assert_equal 12, member.waiting_billing_year_division
  end

  test "sets last organization billing_year_divisions by default" do
    Current.org.billing_year_divisions = [ 4, 12 ]
    member = members(:aria)
    member.update(waiting_billing_year_division: 1)

    assert_equal 12, member.waiting_billing_year_division
  end

  test "only accepts organization billing_year_divisions" do
    Current.org.billing_year_divisions = [ 1, 12 ]
    member = members(:aria)

    member.update(waiting_billing_year_division: 3)
    assert_equal 12, member.waiting_billing_year_division

    member.update(waiting_billing_year_division: 1)
    assert member.save!
  end

  test "validates email presence, but only on public creation" do
    member = build_member(emails: "")
    assert member.valid?

    member.public_create = true
    assert_not member.valid?
    assert_includes member.errors[:emails], "can't be blank"
  end

  test "validates email format" do
    member = build_member(emails: "doe.com, boby@doe.com")
    assert_not member.valid?
    assert_includes member.errors[:emails], "is invalid"

    member.emails = "foo@bar.com;boby@doe.com"
    assert_includes member.errors[:emails], "is invalid"
  end

  test "validates email uniqueness" do
    member = Member.new(emails: "jen@doe.com, JANE@doe.com")
    assert_not member.valid?
    assert_includes member.errors[:emails], "has already been taken"
  end

  test "validates email uniqueness even when emails includes other ones" do
    members(:john).update(emails: "john@DOE.com, john@example.com, super-super@DOE.com")

    assert build_member(emails: "super@DOE.com").valid?
    assert_not build_member(emails: "super-super@DOE.com").valid?
    assert_not Member.new(emails: "john@example.com").valid?
  end

  test "validates annual_fee to be greater or equal to zero" do
    assert build_member(annual_fee: nil).valid?
    assert build_member(annual_fee: 0).valid?
    assert build_member(annual_fee: 1).valid?
    assert_not build_member(annual_fee: -1).valid?
  end

  test "validates positive annual_fee for new support member" do
    org(annual_fee: 0, annual_fee_member_form: true)
    member = build_member(annual_fee: nil, public_create: true)
    assert_not member.valid?
    assert_includes member.errors[:annual_fee], "must be greater than or equal to 1"

    member.update(annual_fee: 0, waiting_basket_size_id: 0)
    assert_not member.valid?
    assert_includes member.errors[:annual_fee], "must be greater than or equal to 1"

    member.update(annual_fee: 1)
    assert member.valid?

    member.update(annual_fee: 0, waiting_basket_size_id: 1)
    assert member.valid?

    member.update(public_create: false)
    assert member.valid?
  end

  test "validates waiting_basket_size presence when a depot is set" do
    member = build_member(
      waiting_basket_size: nil,
      waiting_depot: depots(:farm))

    assert_not member.valid?
    assert_includes member.errors[:waiting_basket_size_id], "can't be blank"
  end

  test "validates waiting_basket_price_extra presence" do
    member = build_member(
      public_create: true,
      waiting_depot: depots(:farm),
      waiting_basket_price_extra: nil)

    assert_not member.valid?
    assert_includes member.errors[:waiting_basket_price_extra], "can't be blank"
  end

  test "validates waiting_depot presence" do
    member = build_member(
      waiting_basket_size: basket_sizes(:small),
      waiting_depot: nil)

    assert_not member.valid?
    assert_includes member.errors[:waiting_depot_id], "can't be blank"
  end

  test "validates desired_shares_number on public create" do
    org(annual_fee: 50, share_price: nil, shares_number: nil)
    member = build_member(desired_shares_number: 0)
    member.public_create = nil
    assert member.valid?
    member.public_create = true
    assert member.valid?

    org(annual_fee: nil, share_price: 100, shares_number: 1)
    member.public_create = nil
    assert member.valid?
    member.public_create = true
    assert_not member.valid?
    member.update(desired_shares_number: 1)
    assert member.valid?

    org(annual_fee: nil, share_price: 100, shares_number: 2)
    assert_not member.valid?
    member.update(desired_shares_number: 2)
    assert member.valid?

    basket_size = basket_sizes(:small)
    basket_size.update(shares_number: 3)
    member.update(waiting_basket_size_id: basket_size.id)
    assert_not member.valid?
    member.update(desired_shares_number: 3)
    assert member.valid?
  end

  test "validates waiting_activity_participations_demanded_annually on public create" do
    member = build_member(
      waiting_activity_participations_demanded_annually: nil,
      public_create: true)

    org(activity_participations_form_min: 2)
    member.update(waiting_activity_participations_demanded_annually: 1)
    assert_not member.valid?
    member.update(waiting_activity_participations_demanded_annually: 2)
    assert member.valid?

    org(activity_participations_form_max: 4)
    member.update(waiting_activity_participations_demanded_annually: 5)
    assert_not member.valid?
    member.update(waiting_activity_participations_demanded_annually: 4)
    assert member.valid?
    member.update(waiting_activity_participations_demanded_annually: 3)
    assert member.valid?
  end

  test "required profession mode on public create" do
    member = build_member(public_create: true, profession: nil)
    org(member_profession_form_mode: "visible")
    assert member.valid?

    org(member_profession_form_mode: "required")
    assert_not member.valid?
  end

  test "required come_form mode on public create" do
    member = build_member(public_create: true, come_from: nil)
    org(member_come_from_form_mode: "visible")
    assert member.valid?

    org(member_come_from_form_mode: "required")
    assert_not member.valid?
  end

  test "validates mandate signed on presence with SEPA" do
    org(country_code: "DE", iban: "DE89370400440532013000")
    member = build_member(sepa_mandate_id: "123", sepa_mandate_signed_on: nil)
    assert_not member.valid?
    assert_includes member.errors[:sepa_mandate_signed_on], "can't be blank"
  end

  test "validates IBAN with SEPA" do
    org(country_code: "DE", iban: "DE89370400440532013000")
    member = build_member(
      country_code: "DE",
      sepa_mandate_id: "123",
      sepa_mandate_signed_on: 1.day.ago,
      iban: nil)
    assert_not member.valid?
    member.update(iban: "CH9300762011623852957")
    assert_not member.valid?
    member.update(iban: "DE89370400440532013333")
    assert_not member.valid? # check digit is invalid
    member.update(iban: "DE21500500009876543210")
    assert member.valid?
  end

  test "sepa_metadata / sepa?" do
    member = build_member(name: "John Doe")
    assert_empty member.sepa_metadata
    assert_not member.sepa?

    member.iban = "DE89370400440532013000"
    member.sepa_mandate_id = "123"
    member.sepa_mandate_signed_on = "2024-01-01"
    assert_equal({
      name: "John Doe",
      iban: "DE89370400440532013000",
      mandate_id: "123",
      mandate_signed_on: Date.parse("2024-01-01")
    }, member.sepa_metadata)
    assert member.sepa?
  end

  test "strips whitespaces from emails and downcase" do
    member = Member.new(emails: " foo@Gmail.COM ")
    assert_equal [ "foo@gmail.com" ], member.emails_array
  end

  test "initializes with annual_fee from organization" do
    org(annual_fee: 42)
    assert_equal 42, Member.new.annual_fee
  end

  test "initializes with organization country code" do
    assert_equal "CH", Member.new.country_code
    org(country_code: "DE", iban: "DE89370400440532013000")
    assert_equal "DE", Member.new.country_code
  end

  test "updates waiting basket_size/depot" do
    member = members(:aria)
    new_basket_size = basket_sizes(:small)
    new_depot = depots(:home)
    member.update!(waiting_basket_size: new_basket_size, waiting_depot: new_depot)
    assert_equal "waiting", member.state
    assert member.waiting_started_at.present?
    assert_equal new_basket_size, member.waiting_basket_size
    assert_equal new_depot, member.waiting_depot
  end

  test "current_membership" do
    travel_to "2024-01-01"
    member = members(:john)
    assert_equal memberships(:john), member.current_membership
  end

  test "billable? support member" do
    member = members(:martha)
    assert member.billable?
  end

  test "billable? inactive member" do
    member = members(:mary)
    assert_not member.billable?
  end

  test "billable? past membership" do
    travel_to "2026-01-01"
    member = members(:john)
    assert_not member.billable?
  end

  test "billable? ongoing membership" do
    travel_to "2024-01-01"
    member = members(:john)
    assert member.billable?
  end

  test "billable? future membership" do
    travel_to "2025-01-01"
    member = members(:john)
    assert member.billable?
  end

  test "update_trial_baskets! ignore absent basket" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    memberships(:john_past).update_column(:renewed_at, nil)
    memberships(:john_past).update!(started_on: "2023-05-29")
    create_absence(member: members(:john), started_on: "2023-06-01", ended_on: "2024-04-05")

    members(:john).update_trial_baskets!
    range = Date.new(2023, 5, 25)..Date.new(2024, 4, 15)

    assert_equal [
      [ "2023-05-29", true ],
      [ "2023-06-05", false ],
      [ "2024-04-01", false ],
      [ "2024-04-08", true ],
      [ "2024-04-15", false ]
    ], members(:john).baskets.between(range).map { |b| [ b.delivery.date.to_s, b.trial? ] }
  end

  test "update_trial_baskets! only consider baskets from continuous previous memberships" do
    travel_to "2025-01-01"
    org(trial_baskets_count: 2)
    memberships(:john_past).update_column(:renewed_at, nil)
    memberships(:john_past).update!(started_on: "2023-05-22")
    memberships(:john).destroy

    members(:john).update_trial_baskets!
    range = Date.new(2023, 5, 22)..Date.new(2025, 4, 21)

    assert_equal [
     [ "2023-05-22", true ],
     [ "2023-05-29", true ],
     [ "2023-06-05", false ],
     [ "2025-04-07", true ],
     [ "2025-04-14", true ],
     [ "2025-04-21", false ]
    ], members(:john).baskets.between(range).map { |b| [ b.delivery.date.to_s, b.trial? ] }
  end

  test "update_trial_baskets! with member trial_baskets_count" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    members(:jane).update!(trial_baskets_count: 3)
    range = Date.new(2024, 1, 1)..Date.new(2024, 5, 1)

    assert_equal [
     [ "2024-04-04", true ],
     [ "2024-04-11", true ],
     [ "2024-04-18", true ],
     [ "2024-04-25", false ]
    ], members(:jane).baskets.between(range).map { |b| [ b.delivery.date.to_s, b.trial? ] }
  end

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

  test "emails= / emails" do
    member = Member.new(emails: "john@doe.com, foo@bar.com")
    assert_equal "john@doe.com, foo@bar.com", member.emails
  end

  test "phones= / phones with two phones" do
    member = members(:john)
    member.update(phones: "123456789, 987654321, ")
    assert_equal "+41123456789, +41987654321", member.phones
  end

  test "phones= / phones with two phones with spaces and dots" do
    member = members(:john)
    member.update(phones: "+41.12.345/67 89, 987/6543 21, ")
    assert_equal "+41123456789, +41987654321", member.phones
  end

  test "phones= / phones with other country phone" do
    org(country_code: "DE", iban: "DE89370400440532013000")
    member = members(:john)
    member.update(phones: "987 6543 21, ", country_code: "FR")
    assert_equal "+33987654321", member.phones
  end

  test "phones= / phones with organization country code" do
    org(country_code: "DE", iban: "DE89370400440532013000")
    member = members(:john)
    member.update(phones: "987 6543 21, ", country_code: nil)
    assert_equal "+49987654321", member.phones
  end

  test "absent? returns true for a given date during the absence window" do
    travel_to "2024-05-1"
    absence = create_absence(
      member: members(:john),
      started_on: 2.weeks.from_now,
      ended_on: 4.weeks.from_now)
    assert absence.member.absent?(3.weeks.from_now)
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
    assert_equal -2, member.required_shares_number
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

  test "deactivate! removing negative number" do
    org(share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:martha)
    member.update(existing_shares_number: 2, required_shares_number: -2)
    assert_changes -> { member.state }, from: "inactive", to: "support" do
      member.update!(required_shares_number: 0)
    end
    assert_equal 0, member.desired_shares_number
    assert_equal 2, member.shares_number
  end

  test "missing_shares_number when desired_shares_number only" do
    member = Member.new(desired_shares_number: 10, existing_shares_number: 0)
    assert_equal 10, member.missing_shares_number
  end

  test "missing_shares_number when matching existing_shares_number" do
    member = Member.new(desired_shares_number: 5, existing_shares_number: 5)
    assert_equal 0, member.missing_shares_number
  end

  test "missing_shares_number when more existing_shares_number" do
    member = Member.new(desired_shares_number: 5, existing_shares_number: 6)
    assert_equal 0, member.missing_shares_number
  end

  test "missing_shares_number when less existing_shares_number" do
    member = Member.new(desired_shares_number: 6, existing_shares_number: 4)
    assert_equal 2, member.missing_shares_number
  end

  test "missing_shares_number when requiring more membership shares" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:medium)
    basket_size.update!(shares_number: 2)
    member = members(:john)
    member.update(desired_shares_number: 1, existing_shares_number: 0)
    assert_equal 2, member.missing_shares_number
  end

  test "missing_shares_number when explicitly requiring more shares" do
    member =  Member.new(desired_shares_number: 1, existing_shares_number: 0, required_shares_number: 3)
    assert_equal 3, member.missing_shares_number
  end

  test "missing_shares_number when explicitly requiring less shares and desired none" do
    member = Member.new(desired_shares_number: 0, existing_shares_number: 0, required_shares_number: 0)
    assert_equal 0, member.missing_shares_number
  end

  test "missing_shares_number when explicitly requiring less shares but still desired one" do
    member = Member.new(desired_shares_number: 1, existing_shares_number: 0, required_shares_number: 0)
    assert_equal 1, member.missing_shares_number
  end

  test "can_destroy? can destroy pending user" do
    member = Member.new(state: "pending")
    assert member.can_destroy?
  end

  test "can_destroy? can destroy inactive member with no memberships and no invoices" do
    member = members(:mary)
    assert member.can_destroy?
  end

  test "can_destroy? cannot destroy inactive member with membership" do
    travel_to "2026-01-01"
    member = members(:john)
    member.update_columns(state: "inactive")
    assert member.memberships.many?
    assert_not member.can_destroy?
  end

  test "can_destroy? cannot destroy inactive member with invoices" do
    member = members(:martha)
    member.update_columns(state: "inactive")
    assert member.invoices.one?
    assert_not member.can_destroy?
  end

  test "set default annual_fee when support member" do
    org(annual_fee_support_member_only: false)
    member = build_member(annual_fee: nil)
    assert_equal 30, member.annual_fee

    member = build_member(annual_fee: nil, waiting_basket_size_id: small_id)
    assert_equal 30, member.annual_fee

    org(annual_fee_support_member_only: true)
    member = build_member(annual_fee: nil)
    assert_equal 30, member.annual_fee

    member = build_member(annual_fee: nil, waiting_basket_size_id: small_id)
    assert_nil member.annual_fee
  end

  test "set_default_waiting_delivery_cycle when basket_size has a delivery_cycle" do
    delivery_cycle = delivery_cycles(:thursdays)
    basket_size = basket_sizes(:small)
    basket_size.update(delivery_cycle: delivery_cycle)
    member = members(:aria)
    member.update!(waiting_basket_size: basket_size, waiting_delivery_cycle_id: nil)
    assert_equal delivery_cycle, member.waiting_delivery_cycle
  end

  test "set_default_waiting_delivery_cycle when basket_size has no delivery_cycle" do
    member = members(:aria)
    member.update!(waiting_delivery_cycle_id: nil)
    assert_equal delivery_cycles(:all), member.waiting_delivery_cycle
  end
end
