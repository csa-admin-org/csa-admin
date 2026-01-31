# frozen_string_literal: true

require "test_helper"

class Member::AnonymizationTest < ActiveSupport::TestCase
  # === Guard conditions ===

  test "anonymize! raises error if member is not discarded" do
    member = create_member
    member.update_columns(state: "inactive")

    error = assert_raises(RuntimeError) { member.anonymize! }
    assert_equal "Cannot anonymize non-discarded member ##{member.id}", error.message
  end

  test "anonymize! raises error if member is already anonymized" do
    member = discardable_member
    member.discard
    member.anonymize!

    error = assert_raises(RuntimeError) { member.anonymize! }
    assert_equal "Member ##{member.id} is already anonymized", error.message
  end

  # === can_anonymize? ===

  test "can_anonymize? returns false for non-discarded member" do
    member = discardable_member
    assert_not member.can_anonymize?
  end

  test "can_anonymize? returns true for discarded non-anonymized member" do
    member = discardable_member
    member.discard
    assert member.can_anonymize?
  end

  test "can_anonymize? returns false for already anonymized member" do
    member = discardable_member
    member.discard
    member.anonymize!
    assert_not member.can_anonymize?
  end

  # === anonymized? ===

  test "anonymized? returns false before anonymization" do
    member = discardable_member
    member.discard
    assert_not member.anonymized?
  end

  test "anonymized? returns true after anonymization" do
    member = discardable_member
    member.discard
    member.anonymize!
    assert member.anonymized?
  end

  # === Member PII anonymization ===

  test "anonymize! sets name to Anonymized #ID" do
    member = discardable_member
    member.discard
    member.anonymize!

    assert_equal "Anonymized ##{member.id}", member.reload.name
  end

  test "anonymize! clears contact information" do
    member = discardable_member
    member.discard
    member.anonymize!
    member.reload

    assert_nil member.emails
    assert_nil member.phones
  end

  test "anonymize! clears address fields" do
    member = discardable_member
    member.discard
    member.anonymize!
    member.reload

    assert_nil member.street
    assert_nil member.zip
    assert_nil member.city
    assert_nil member.country_code
  end

  test "anonymize! clears billing information" do
    member = discardable_member
    member.update_columns(
      billing_email: "billing@example.com",
      billing_name: "Billing Name",
      billing_street: "Billing Street",
      billing_zip: "12345",
      billing_city: "Billing City"
    )
    member.discard
    member.anonymize!
    member.reload

    assert_nil member.billing_email
    assert_nil member.billing_name
    assert_nil member.billing_street
    assert_nil member.billing_zip
    assert_nil member.billing_city
  end

  test "anonymize! clears notes and personal info" do
    member = discardable_member
    member.update_columns(
      note: "Some note",
      delivery_note: "Delivery note",
      food_note: "Food note",
      profession: "Developer",
      come_from: "Friend"
    )
    member.discard
    member.anonymize!
    member.reload

    assert_nil member.note
    assert_nil member.delivery_note
    assert_nil member.food_note
    assert_nil member.profession
    assert_nil member.come_from
  end

  test "anonymize! clears SEPA information" do
    member = discardable_member
    member.update_columns(
      iban: "DE89370400440532013000",
      sepa_mandate_id: "MANDATE-123",
      sepa_mandate_signed_on: Date.current
    )
    member.discard
    member.anonymize!
    member.reload

    assert_nil member.iban
    assert_nil member.sepa_mandate_id
    assert_nil member.sepa_mandate_signed_on
  end

  test "anonymize! sets contact_sharing to false" do
    member = discardable_member
    member.update_columns(contact_sharing: true)
    member.discard
    member.anonymize!

    assert_not member.reload.contact_sharing
  end

  test "anonymize! sets anonymized_at timestamp" do
    member = discardable_member
    member.discard

    freeze_time do
      member.anonymize!
      assert_equal Time.current, member.reload.anonymized_at
    end
  end

  # === Related records: Absences ===

  test "anonymize! clears absence notes" do
    member = discardable_member
    absence = member.absences.create!(
      started_on: 1.month.from_now,
      ended_on: 2.months.from_now,
      note: "Vacation in Hawaii",
      admin: true
    )
    member.discard
    member.anonymize!

    assert_nil absence.reload.note
  end

  test "anonymize! nullifies session_id on absences" do
    member = discardable_member
    session = member.sessions.first
    absence = member.absences.create!(
      started_on: 1.month.from_now,
      ended_on: 2.months.from_now,
      session: session,
      admin: true
    )
    member.discard
    member.anonymize!

    assert_nil absence.reload.session_id
  end

  # === Related records: ActivityParticipation ===

  test "anonymize! clears activity participation PII" do
    member = discardable_member
    activity = activities(:harvest)
    participation = member.activity_participations.create!(
      activity: activity,
      participants_count: 1,
      note: "Will bring tools",
      carpooling_phone: "+41 79 123 45 67",
      carpooling_city: "Zurich"
    )
    member.discard
    member.anonymize!
    participation.reload

    assert_nil participation.note
    assert_nil participation.read_attribute(:carpooling_phone)
    assert_nil participation.carpooling_city
  end

  test "anonymize! nullifies session_id on activity participations" do
    member = discardable_member
    session = member.sessions.first
    activity = activities(:harvest)
    participation = member.activity_participations.create!(
      activity: activity,
      participants_count: 1,
      session: session
    )
    member.discard
    member.anonymize!

    assert_nil participation.reload.session_id
  end

  # === Related records: Newsletter::Delivery ===

  test "anonymize! deletes newsletter deliveries" do
    member = discardable_member
    newsletter = newsletters(:simple)
    Newsletter::Delivery.create!(
      newsletter: newsletter,
      member: member,
      email: "test@example.com",
      state: "delivered",
      processed_at: Time.current
    )
    assert member.newsletter_deliveries.any?

    member.discard
    member.anonymize!

    assert_empty member.newsletter_deliveries.reload
  end

  # === Related records: ActiveAdmin::Comment ===

  test "anonymize! deletes comments on member" do
    member = discardable_member
    admin = admins(:super)
    ActiveAdmin::Comment.create!(
      resource: member,
      body: "Note about member",
      author: admin,
      namespace: "admin"
    )

    member.discard
    assert_difference "ActiveAdmin::Comment.count", -1 do
      member.anonymize!
    end
  end

  test "anonymize! deletes comments on member absences" do
    member = discardable_member
    admin = admins(:super)
    absence = member.absences.create!(
      started_on: 1.month.from_now,
      ended_on: 2.months.from_now,
      admin: true
    )
    ActiveAdmin::Comment.create!(
      resource: absence,
      body: "Note about absence",
      author: admin,
      namespace: "admin"
    )

    member.discard
    assert_difference "ActiveAdmin::Comment.count", -1 do
      member.anonymize!
    end
  end

  test "anonymize! deletes comments on member activity participations" do
    member = discardable_member
    admin = admins(:super)
    activity = activities(:harvest)
    participation = member.activity_participations.create!(
      activity: activity,
      participants_count: 1
    )
    ActiveAdmin::Comment.create!(
      resource: participation,
      body: "Note about participation",
      author: admin,
      namespace: "admin"
    )

    member.discard
    assert_difference "ActiveAdmin::Comment.count", -1 do
      member.anonymize!
    end
  end

  test "anonymize! deletes comments on member payments" do
    member = discardable_member
    admin = admins(:super)
    payment = member.payments.create!(amount: 100, date: Date.current)
    ActiveAdmin::Comment.create!(
      resource: payment,
      body: "Note about payment",
      author: admin,
      namespace: "admin"
    )

    member.discard
    assert_difference "ActiveAdmin::Comment.count", -1 do
      member.anonymize!
    end
  end

  test "anonymize! deletes comments on member invoices" do
    member = discardable_member
    admin = admins(:super)
    invoice = member.invoices.create!(
      date: Date.current,
      entity_type: "AnnualFee",
      annual_fee: 30
    )
    ActiveAdmin::Comment.create!(
      resource: invoice,
      body: "Note about invoice",
      author: admin,
      namespace: "admin"
    )

    member.discard
    assert_difference "ActiveAdmin::Comment.count", -1 do
      member.anonymize!
    end
  end

  test "anonymize! deletes comments on member memberships" do
    travel_to "2024-01-01"
    member = discardable_member
    admin = admins(:super)
    membership = create_membership(member: member)
    ActiveAdmin::Comment.create!(
      resource: membership,
      body: "Note about membership",
      author: admin,
      namespace: "admin"
    )

    travel_to "2026-01-01" # Move past membership end
    member.discard
    assert_difference "ActiveAdmin::Comment.count", -1 do
      member.anonymize!
    end
  end

  test "anonymize! deletes comments on member shop orders" do
    member = discardable_member
    admin = admins(:super)
    order = create_shop_order(member: member, state: "delivered")
    ActiveAdmin::Comment.create!(
      resource: order,
      body: "Note about shop order",
      author: admin,
      namespace: "admin"
    )

    member.discard
    assert_difference "ActiveAdmin::Comment.count", -1 do
      member.anonymize!
    end
  end

  # === Related records: Audits ===

  test "anonymize! deletes member audits" do
    member = discardable_member
    # Create an audit by updating the member
    member.update!(note: "Some note")
    assert member.audits.any?

    member.discard
    member.anonymize!

    assert_empty member.audits.reload
  end

  # === Sessions ===

  test "anonymize! deletes all member sessions" do
    member = discardable_member
    # discardable_member creates a session
    assert member.sessions.any?

    member.discard
    member.anonymize!

    assert_empty member.sessions.reload
  end

  # === Preserved data ===

  test "anonymize! preserves discarded_at timestamp" do
    member = discardable_member
    member.discard
    discarded_at = member.discarded_at

    member.anonymize!

    assert_equal discarded_at, member.reload.discarded_at
  end

  test "anonymize! preserves language" do
    member = discardable_member
    member.update_columns(language: "fr")
    member.discard
    member.anonymize!

    assert_equal "fr", member.reload.language
  end

  test "anonymize! preserves memberships_count" do
    member = discardable_member
    original_count = member.memberships_count
    member.discard
    member.anonymize!

    assert_equal original_count, member.reload.memberships_count
  end

  # === Transaction behavior ===

  test "anonymize! runs in a transaction" do
    member = discardable_member
    member.discard

    # Simulate a failure during anonymization by using a bad SQL update
    # that will cause an error after some operations have run
    Member::Anonymization.class_eval do
      alias_method :original_delete_audits!, :delete_audits!
      define_method(:delete_audits!) { raise "Simulated error" }
    end

    assert_raises(RuntimeError) { member.anonymize! }

    # Restore original method
    Member::Anonymization.class_eval do
      alias_method :delete_audits!, :original_delete_audits!
      remove_method :original_delete_audits!
    end

    # Member should not be anonymized due to rollback
    assert_not member.reload.anonymized?
    assert_not_equal "Anonymized ##{member.id}", member.name
  end
end
