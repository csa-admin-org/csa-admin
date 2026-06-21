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

  test "redeem token is tenant-specific" do
    session = create_session(admins(:ultra))
    token = session.generate_token_for(:redeem)

    with_tenant("other") do
      assert_nil Session.find_by_token_for(:redeem, token)
      assert_nil Session.redeem_token(token, owner_type: :admin)
    end
  end

  test "redeem token can only be used once" do
    session = create_session(admins(:ultra))
    token = session.generate_token_for(:redeem)

    assert_equal session, Session.redeem_token(token, owner_type: :admin)
    assert_predicate session.reload, :redeemed_at?
    assert_nil Session.redeem_token(token, owner_type: :admin)
  end

  test "redeem token is invalidated when the session is revoked" do
    session = create_session(admins(:ultra))
    token = session.generate_token_for(:redeem)

    session.revoke!

    assert_nil Session.redeem_token(token, owner_type: :admin)
  end

  test "redeem token must match the expected owner type" do
    session = create_session(members(:john))
    token = session.generate_token_for(:redeem)

    assert_nil Session.redeem_token(token, owner_type: :admin)
    assert_nil session.reload.redeemed_at
  end

  test "redeem token is rejected for expired session" do
    session = create_session(admins(:ultra))
    session.update!(created_at: Session::EXPIRATION.ago - 1.second)
    token = session.generate_token_for(:redeem)

    assert_nil Session.redeem_token(token, owner_type: :admin)
    assert_nil session.reload.redeemed_at
  end

  test "redeem token is rejected for unusable session" do
    session = create_session(admins(:ultra))
    session.update!(email: nil)
    token = session.generate_token_for(:redeem)

    assert_nil Session.redeem_token(token, owner_type: :admin)
    assert_nil session.reload.redeemed_at
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
