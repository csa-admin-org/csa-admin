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

  # discardability_reasons tests

  test "discardability_reasons returns empty array for eligible member" do
    member = members(:mary) # inactive member
    assert member.inactive?
    assert_empty member.discardability_reasons
  end

  test "discardability_reasons includes :not_inactive for active member" do
    member = members(:john) # active member
    assert member.active?
    assert_includes member.discardability_reasons, :not_inactive
  end

  test "discardability_reasons includes :not_inactive for waiting member" do
    member = members(:aria) # waiting member
    assert member.waiting?
    assert_includes member.discardability_reasons, :not_inactive
  end

  test "discardability_reasons includes :not_inactive for support member" do
    member = members(:martha) # support member
    assert member.support?
    assert_includes member.discardability_reasons, :not_inactive
  end

  test "discardability_reasons includes :open_invoices when processing invoices exist" do
    member = members(:mary)
    Invoice.create!(member: member, date: Date.current, entity_type: "AnnualFee", annual_fee: 30)
    perform_enqueued_jobs
    invoice = member.invoices.last
    invoice.update_column(:state, "processing")

    assert_includes member.discardability_reasons, :open_invoices
  end

  test "discardability_reasons includes :open_invoices when open invoices exist" do
    member = members(:mary)
    Invoice.create!(member: member, date: Date.current, entity_type: "AnnualFee", annual_fee: 30)
    perform_enqueued_jobs

    assert_includes member.discardability_reasons, :open_invoices
  end

  test "discardability_reasons excludes :open_invoices when only closed invoices exist" do
    member = members(:mary)
    Invoice.create!(member: member, date: Date.current, entity_type: "AnnualFee", annual_fee: 30)
    perform_enqueued_jobs
    member.invoices.last.update_column(:state, "closed")

    assert_not_includes member.discardability_reasons, :open_invoices
  end

  test "discardability_reasons includes :billable_memberships when billable membership exists" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update_column(:state, "inactive")
    # Jane has a current membership from fixtures that is billable

    assert_includes member.discardability_reasons, :billable_memberships
  end

  test "discardability_reasons includes :pending_shop_orders when pending orders exist" do
    travel_to "2024-04-01"
    org(features: %w[shop])
    member = members(:mary)
    member.update!(shop_depot_id: depots(:farm).id)

    delivery = deliveries(:thursday_1)
    delivery.update!(shop_open: true)

    order = Shop::Order.create!(member: member, delivery: delivery)
    order.update_column(:state, "pending")

    assert_includes member.discardability_reasons, :pending_shop_orders
  end

  test "discardability_reasons can return multiple reasons" do
    travel_to "2024-01-01"
    member = members(:jane) # active member with memberships
    Invoice.create!(member: member, date: Date.current, entity_type: "AnnualFee", annual_fee: 30)
    perform_enqueued_jobs

    reasons = member.discardability_reasons

    assert_includes reasons, :not_inactive
    assert_includes reasons, :open_invoices
    assert_includes reasons, :billable_memberships
  end

  test "can_discard? returns true when discardability_reasons is empty" do
    member = members(:mary)
    assert_empty member.discardability_reasons
    assert member.can_discard?
  end

  test "can_discard? returns false when discardability_reasons is not empty" do
    member = members(:john)
    assert_not_empty member.discardability_reasons
    assert_not member.can_discard?
  end
end
