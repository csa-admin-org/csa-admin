# frozen_string_literal: true

require "test_helper"

class Member::DiscardableTest < ActiveSupport::TestCase
  test "display_id returns id for kept member" do
    member = members(:john)
    assert_not member.discarded?
    assert_equal member.id, member.display_id
  end

  test "display_id returns id for discarded but not anonymized member" do
    member = members(:mary)
    member.update_columns(state: "inactive", discarded_at: Time.current)
    assert_equal member.id, member.display_id
  end

  test "display_id returns nil for anonymized member" do
    member = members(:mary)
    member.update_columns(state: "inactive", discarded_at: Time.current, anonymized_at: Time.current)
    assert_nil member.display_id
  end

  test "exports do not leak raw member_id" do
    # Patterns that indicate raw member_id usage in exports (without safe display_id wrapper)
    dangerous_patterns = [
      # column(:member_id) or column :member_id without a block
      /column\s*[\(:]?\s*:?member_id\s*\)?(?:\s*,|\s*$)/,
      # &:member_id shorthand
      /&:member_id/,
      # Direct .member_id or .member.id in map blocks for exports
      /\.map\s*\{[^}]*\.member_id\s*\}/,
      /\.map\s*\{[^}]*\.member\.id\s*\}/,
      /\.map\s*\(&:member_id\)/
    ]

    # Files that contain export code (CSV blocks, XLSX builders)
    export_files = Dir.glob(Rails.root.join("app/admin/**/*.rb")) +
                   Dir.glob(Rails.root.join("app/models/xlsx/**/*.rb")) +
                   Dir.glob(Rails.root.join("app/models/**/*csv*.rb"))

    violations = []

    export_files.each do |file|
      content = File.read(file)
      relative_path = Pathname.new(file).relative_path_from(Rails.root)

      # Only check within csv do blocks for admin files
      if file.include?("/admin/")
        # Extract csv do ... end blocks
        csv_blocks = content.scan(/csv do.*?^  end/m)
        check_content = csv_blocks.join("\n")
      else
        check_content = content
      end

      dangerous_patterns.each do |pattern|
        if check_content.match?(pattern)
          violations << "#{relative_path}: matches #{pattern.inspect}"
        end
      end
    end

    assert_empty violations,
      "Found raw member_id usage in exports (use member&.display_id instead):\n  #{violations.join("\n  ")}"
  end
end
