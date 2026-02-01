# frozen_string_literal: true

require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "email must not be suppressed" do
    session = sessions(:john)
    assert session.valid?

    EmailSuppression.suppress!(session.email,
      stream_id: "broadcast",
      origin: "Recipient",
      reason: "HardBounce")
    assert session.valid?

    EmailSuppression.suppress!(session.email,
      stream_id: "outbound",
      origin: "Recipient",
      reason: "HardBounce")
    assert_not session.valid?
  end

  test "usable scope with email and not revoked" do
    session = sessions(:john)
    session.update!(revoked_at: nil)
    assert_includes members(:john).sessions.usable, session
  end

  test "usable scope without email" do
    session = sessions(:john)
    session.update!(email: nil)
    assert_empty members(:john).sessions.usable
  end

  test "usable scope revoked" do
    session = sessions(:john)
    session.update!(revoked_at: Time.current)
    assert_empty members(:john).sessions.usable
  end

  test "expired after a year" do
    travel_to "2025-01-01"
    session = Session.new(email: "john@doe.com", created_at: Time.current)
    assert_not session.expired?

    travel 1.year + 1.second
    assert session.expired?
  end

  test "expires after an hour for member session originated from admin" do
    travel_to "2025-01-01"
    session = Session.new(
      admin: admins(:ultra),
      member: members(:john),
      created_at: Time.current)

    assert session.admin_originated?
    assert_not session.expired?

    travel 6.hours + 1.second
    assert session.expired?
  end

  test "revoke!" do
    session = sessions(:john)

    assert_changes -> { session.revoked_at }, from: nil do
      session.revoke!
    end

    assert session.revoked?
  end

  test "cannot find discarded member by email" do
    member = discardable_member
    email = member.emails_array.first
    member.discard

    session = Session.new(remote_addr: "127.0.0.1", user_agent: "Test Browser")
    session.member_email = email

    assert_nil session.member
    assert_not session.valid?
  end
end
