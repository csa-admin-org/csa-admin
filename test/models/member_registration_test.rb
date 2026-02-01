# frozen_string_literal: true

require "test_helper"

class MemberRegistrationTest < ActiveSupport::TestCase
  def register(member, params)
    registration = MemberRegistration.new(member, params)
    registration.save
    registration.member
  end

  test "do not persist invalid member" do
    member = build_member(name: "")

    assert_no_difference "Member.count" do
      member = register(member, {})
    end

    assert_not member.persisted?
    assert_not member.valid?
    assert_includes member.errors[:name], "can't be blank"
  end

  test "persist valid new member" do
    admin = admins(:ultra)
    admin.update!(notifications: %w[ new_registration ])

    member = build_member(name: "Dylan Doe")

    assert_difference "Member.count", 1 do
      register(member, {})
    end

    assert member.persisted?
    perform_enqueued_jobs

    assert_equal 1, AdminMailer.deliveries.size
    mail = AdminMailer.deliveries.last
    assert_equal "New registration", mail.subject
    assert_equal [ admin.email ], mail.to
    assert_includes mail.body.encoded, admin.name
    assert_includes mail.body.encoded, "Dylan Doe"
  end

  test "do not persist invalid new member and clear emails taken errors" do
    email = members(:john).emails_array.first
    member = build_member(emails: "#{email}, wrong", phones: nil)
    member.public_create = true

    assert_no_difference "Member.count" do
      member = register(member, { phones: "not a phone" })
    end

    assert_not member.persisted?
    assert_includes member.errors[:phones], "can't be blank"
    assert_includes member.errors[:emails], "is invalid"
  end

  test "do not persist existing and active member" do
    email = members(:john).emails_array.first
    member = build_member(emails: email)

    assert_no_difference "Member.count" do
      member = register(member, {})
    end

    assert_not member.valid?
    assert_includes member.errors[:emails], "has already been taken"
  end

  test "put back in waiting list matching inactive member" do
    admin = admins(:ultra)
    admin.update!(notifications: %w[ new_registration ])

    inactive_member = members(:mary)
    email = inactive_member.emails_array.first
    member = build_member(emails: email)

    assert_no_difference "Member.count" do
      assert_changes -> { inactive_member.reload.state }, from: "inactive", to: "waiting" do
        member = register(member, { name: "Mary and John", waiting_basket_size_id: "1" })
      end
    end

    assert member.persisted?
    assert member.valid?
    assert_equal inactive_member.id, member.id
    assert_equal "Mary and John", member.name
    assert_equal 1, member.waiting_basket_size_id

    perform_enqueued_jobs
    assert_equal 1, AdminMailer.deliveries.size
    mail = AdminMailer.deliveries.last
    assert_equal "New re-registration", mail.subject
    assert_equal [ admin.email ], mail.to
    assert_includes mail.body.encoded, admin.name
    assert_includes mail.body.encoded, "An existing member"
    assert_includes mail.body.encoded, "Mary and John"
  end

  test "put back in support only matching inactive member" do
    inactive_member = members(:mary)
    email = inactive_member.emails_array.first
    member = build_member(emails: email)

    assert_no_difference "Member.count" do
      assert_changes -> { inactive_member.reload.state }, from: "inactive", to: "support" do
        member = register(member, name: "Mary and John", waiting_basket_size_id: "0")
      end
    end

    assert member.persisted?
    assert member.valid?
    assert_equal inactive_member.id, member.id
    assert_equal "Mary and John", member.name
    assert_nil member.waiting_basket_size_id
    assert_equal 30, member.annual_fee
  end

  test "cannot reuse discarded member" do
    member = discardable_member
    email = member.emails_array.first
    member.discard

    new_member = build_member(emails: email)
    registration = MemberRegistration.new(new_member, {})

    # Should not find the discarded member for reuse
    assert_not registration.save
    # The email is still "taken" by the discarded member
    assert new_member.errors.of_kind?(:emails, :taken)
  end

  test "can use email after member is anonymized" do
    member = discardable_member
    email = member.emails_array.first
    member.discard
    member.anonymize!

    new_member = build_member(emails: email, phones: "+41 79 999 99 99")
    new_member.public_create = true

    # Email should now be available after anonymization cleared it
    assert_empty Member.including_email(email)
    assert_predicate new_member, :valid?, new_member.errors.full_messages.join(", ")
  end
end
