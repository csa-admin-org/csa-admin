# frozen_string_literal: true

require "test_helper"
require_relative "../../db/migrate/20260710141000_add_bank_connection_safety_constraints"

class AddBankConnectionSafetyConstraintsTest < ActiveSupport::TestCase
  test "preflight rejects active connections that are not ready" do
    migration = migration_with_ids([ "7" ])

    error = assert_raises ActiveRecord::MigrationError do
      migration.send(:assert_active_connections_are_ready!)
    end

    assert_equal "Cannot add bank connection safety constraints: active connections must be ready (ids: 7)", error.message.strip
  end

  test "preflight rejects multiple inactive EBICS onboarding rows" do
    migration = migration_with_ids([ "3", "9" ])

    error = assert_raises ActiveRecord::MigrationError do
      migration.send(:assert_single_ebics_onboarding!)
    end

    assert_equal "Cannot add bank connection safety constraints: multiple EBICS onboarding rows exist (ids: 3, 9)", error.message.strip
  end

  test "preflight accepts one or no inactive EBICS onboarding rows" do
    [ [], [ "3" ] ].each do |ids|
      assert_nothing_raised do
        migration_with_ids(ids).send(:assert_single_ebics_onboarding!)
      end
    end
  end

  private

  def migration_with_ids(ids)
    AddBankConnectionSafetyConstraints.new.tap do |migration|
      migration.define_singleton_method(:select_values) { |_sql| ids }
    end
  end
end
