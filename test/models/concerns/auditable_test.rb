# frozen_string_literal: true

require "test_helper"

class AuditableTest < ActiveSupport::TestCase
  test "save changes on audited attributes without session" do
    member = members(:john)
    member.update!(name: "Joe Doe")

    assert_difference("Audit.count", 1) do
      member.update!(name: "John Doe")
    end

    audit = member.audits.last
    assert_equal System.instance, audit.actor
    assert_nil audit.session
    assert_equal({ "name" => [ "Joe Doe", "John Doe" ] }, audit.audited_changes)
  end

  test "save changes on audited attributes with current session" do
    travel_to "2024-01-01"
    member = members(:john)
    session = create_session(member)
    Current.session = session

    assert_difference("Audit.count", 1) do
      member.update!(name: "Joe Doe", note: "Hello")
    end

    audit = member.audits.last
    assert_equal member, audit.actor
    assert_equal session, audit.session
    assert_equal({ "name" => [ "John Doe", "Joe Doe" ], "note" => [ nil, "Hello" ] }, audit.audited_changes)
  end

  test "ignore changes with no present value" do
    member = members(:john)
    member.update!(note: nil)

    assert_no_difference("Audit.count") do
      member.update!(note: "  ")
    end
  end

  test "ignore changes with similar values" do
    member = members(:john)
    member.update!(note: "Foo")

    assert_no_difference("Audit.count") do
      member.update!(note: "  Foo ")
    end
  end
end
