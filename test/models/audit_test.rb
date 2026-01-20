# frozen_string_literal: true

require "test_helper"

class AuditTest < ActiveSupport::TestCase
  test "relevant_for excludes audits created within 1 second of auditable creation" do
    member = members(:john)
    creation_audit = member.audits.create!(
      audited_changes: { "name" => [ nil, "John" ] },
      created_at: member.created_at
    )

    assert_not_includes Audit.relevant_for(member), creation_audit
  end

  test "relevant_for includes audits created after 1 second of auditable creation" do
    member = members(:john)
    update_audit = member.audits.create!(
      audited_changes: { "name" => [ "John", "Johnny" ] },
      created_at: member.created_at + 2.seconds
    )

    assert_includes Audit.relevant_for(member), update_audit
  end

  test "relevant_for only returns audits for the given auditable" do
    john = members(:john)
    jane = members(:jane)

    john_audit = john.audits.create!(
      audited_changes: { "name" => [ "John", "Johnny" ] },
      created_at: john.created_at + 2.seconds
    )
    jane_audit = jane.audits.create!(
      audited_changes: { "name" => [ "Jane", "Janet" ] },
      created_at: jane.created_at + 2.seconds
    )

    assert_includes Audit.relevant_for(john), john_audit
    assert_not_includes Audit.relevant_for(john), jane_audit
  end
end
