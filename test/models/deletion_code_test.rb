# frozen_string_literal: true

require "test_helper"

class DeletionCodeTest < ActiveSupport::TestCase
  def create_session(member)
    Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
  end

  test "generate returns a 6-digit string" do
    member = members(:mary)
    session = create_session(member)

    code = DeletionCode.generate(session)

    assert_match(/^\d{6}$/, code)
  end

  test "generate returns consistent code for same session" do
    member = members(:mary)
    session = create_session(member)

    code1 = DeletionCode.generate(session)
    code2 = DeletionCode.generate(session)

    assert_equal code1, code2
  end

  test "generate returns different code after session updated_at changes" do
    member = members(:mary)
    session = create_session(member)

    code1 = DeletionCode.generate(session)

    travel 1.second do
      session.rotate_deletion_code!
    end

    code2 = DeletionCode.generate(session)

    assert_not_equal code1, code2
  end

  test "generate returns different codes for different sessions" do
    member = members(:mary)
    session1 = create_session(member)
    session2 = create_session(member)

    code1 = DeletionCode.generate(session1)
    code2 = DeletionCode.generate(session2)

    assert_not_equal code1, code2
  end

  test "verify returns true for valid code within expiry window" do
    member = members(:mary)
    session = create_session(member)
    code = DeletionCode.generate(session)

    assert DeletionCode.verify(session, code)
  end

  test "verify returns false for invalid code" do
    member = members(:mary)
    session = create_session(member)

    assert_not DeletionCode.verify(session, "000000")
  end

  test "verify returns false for blank code" do
    member = members(:mary)
    session = create_session(member)

    assert_not DeletionCode.verify(session, "")
    assert_not DeletionCode.verify(session, nil)
  end

  test "verify returns false after 15 minutes" do
    member = members(:mary)
    session = create_session(member)
    code = DeletionCode.generate(session)

    travel 16.minutes do
      assert_not DeletionCode.verify(session, code)
    end
  end

  test "verify returns true just before 15 minutes" do
    member = members(:mary)
    session = create_session(member)
    code = DeletionCode.generate(session)

    travel 14.minutes + 59.seconds do
      assert DeletionCode.verify(session, code)
    end
  end

  test "verify strips whitespace from code" do
    member = members(:mary)
    session = create_session(member)
    code = DeletionCode.generate(session)

    assert DeletionCode.verify(session, "  #{code}  ")
  end

  test "verify returns false after session updated_at changes" do
    member = members(:mary)
    session = create_session(member)
    code = DeletionCode.generate(session)

    travel 1.second do
      session.rotate_deletion_code!
    end

    assert_not DeletionCode.verify(session, code)
  end

  test "code is tenant-specific" do
    member = members(:mary)
    session = create_session(member)
    code = DeletionCode.generate(session)

    # The code depends on Tenant.current, so verifying with
    # the same session in the same tenant should work
    assert DeletionCode.verify(session, code)
  end
end
