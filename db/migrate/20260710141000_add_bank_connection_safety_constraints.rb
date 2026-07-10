# frozen_string_literal: true

class AddBankConnectionSafetyConstraints < ActiveRecord::Migration[8.1]
  def up
    assert_active_connections_are_ready!
    assert_single_ebics_onboarding!

    add_index :bank_connections, :provider,
      unique: true,
      where: "provider = 'ebics' AND active = 0 AND state IN ('initializing', 'waiting_for_bank', 'errored')",
      name: "index_bank_connections_on_inactive_ebics_onboarding"

    add_check_constraint :bank_connections,
      "active = 0 OR state = 'ready'",
      name: "bank_connections_active_requires_ready"
  end

  def down
    remove_check_constraint :bank_connections, name: "bank_connections_active_requires_ready"
    remove_index :bank_connections, name: "index_bank_connections_on_inactive_ebics_onboarding"
  end

  private

  def assert_active_connections_are_ready!
    ids = select_values(<<~SQL.squish)
      SELECT id
      FROM bank_connections
      WHERE active = 1 AND state != 'ready'
    SQL
    return if ids.empty?

    raise ActiveRecord::MigrationError,
      "Cannot add bank connection safety constraints: active connections must be ready (ids: #{ids.join(", ")})"
  end

  def assert_single_ebics_onboarding!
    ids = select_values(<<~SQL.squish)
      SELECT id
      FROM bank_connections
      WHERE provider = 'ebics'
        AND active = 0
        AND state IN ('initializing', 'waiting_for_bank', 'errored')
      ORDER BY id
    SQL
    return if ids.one? || ids.empty?

    raise ActiveRecord::MigrationError,
      "Cannot add bank connection safety constraints: multiple EBICS onboarding rows exist (ids: #{ids.join(", ")})"
  end
end
