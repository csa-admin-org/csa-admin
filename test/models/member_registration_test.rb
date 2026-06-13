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

  test "matching inactive member becomes pending after re-registration" do
    admin = admins(:ultra)
    admin.update!(notifications: %w[ new_registration ])

    inactive_member = members(:mary)
    email = inactive_member.emails_array.first
    member = build_member(emails: email)

    assert_no_difference "Member.count" do
      assert_changes -> { inactive_member.reload.state }, from: "inactive", to: "pending" do
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

  test "matching support member becomes pending after re-registration" do
    support_member = members(:martha)
    email = support_member.emails_array.first
    member = build_member(emails: email)

    assert_no_difference "Member.count" do
      assert_changes -> { support_member.reload.state }, from: "support", to: "pending" do
        member = register(member, { name: "Martha and John", waiting_basket_size_id: "1" })
      end
    end

    assert member.persisted?
    assert member.valid?
    assert_equal support_member.id, member.id
    assert_equal "Martha and John", member.name
  end

  test "support only matching inactive member becomes pending after re-registration" do
    inactive_member = members(:mary)
    email = inactive_member.emails_array.first
    member = build_member(emails: email)

    assert_no_difference "Member.count" do
      assert_changes -> { inactive_member.reload.state }, from: "inactive", to: "pending" do
        member = register(member, name: "Mary and John", waiting_basket_size_id: "0")
      end
    end

    assert member.persisted?
    assert member.valid?
    assert_equal inactive_member.id, member.id
    assert_equal "Mary and John", member.name
    assert_equal 0, member.waiting_basket_size_id
    assert_equal 30, member.annual_fee
  end

  test "matching inactive member becomes pending after re-registration when waiting list is disabled" do
    org(features: Current.org.features - [ :waiting_list ])
    inactive_member = members(:mary)
    email = inactive_member.emails_array.first
    member = build_member(emails: email)

    assert_no_difference "Member.count" do
      assert_changes -> { inactive_member.reload.state }, from: "inactive", to: "pending" do
        member = register(member, { name: "Mary and John", waiting_basket_size_id: "1" })
      end
    end

    assert member.persisted?
    assert member.valid?
    assert_equal inactive_member.id, member.id
    assert_equal "Mary and John", member.name
  end

  test "can reuse discarded member email" do
    member = discardable_member
    email = member.emails_array.first
    member.discard

    new_member = build_member(emails: email, phones: "+41 79 999 99 99", waiting_basket_size_id: 0)
    new_member.public_create = true

    # Email is still in the DB but discarded members should not block reuse
    assert_not_empty Member.including_email(email)
    assert_predicate new_member, :valid?, new_member.errors.full_messages.join(", ")
  end

  test "can use email after member is anonymized" do
    member = discardable_member
    email = member.emails_array.first
    member.discard
    member.anonymize!

    new_member = build_member(emails: email, phones: "+41 79 999 99 99", waiting_basket_size_id: 0)
    new_member.public_create = true

    # Email should now be available after anonymization cleared it
    assert_empty Member.including_email(email)
    assert_predicate new_member, :valid?, new_member.errors.full_messages.join(", ")
  end
end
