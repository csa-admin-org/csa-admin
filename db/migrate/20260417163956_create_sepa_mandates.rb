# frozen_string_literal: true

class CreateSEPAMandates < ActiveRecord::Migration[8.1]
  def up
    create_table :sepa_mandates do |t|
      t.references :member, null: false, index: true
      t.references :session, index: true
      t.string :iban, null: false
      t.string :umr, null: false
      t.date :signed_on, null: false
      t.string :ip
      t.string :user_agent
      t.string :source, null: false
      t.datetime :created_at, null: false
    end

    add_reference :invoices, :sepa_mandate, index: true
    add_foreign_key :invoices, :sepa_mandates, on_delete: :nullify
    add_column :invoices, :sepa_debtor_name, :string
    add_column :members, :sepa_disabled_at, :datetime

    now = Time.current
    mandate_key_to_id = {}

    # --- Step A -------------------------------------------------------
    # Build a SEPAMandate row for every unique (member_id, iban, umr,
    # signed_on) variation found in invoice sepa_metadata.  All invoices
    # sharing the same tuple are linked to the same mandate row.
    invoices = connection.select_all(<<~SQL)
      SELECT id, member_id, sepa_metadata, created_at
      FROM invoices
      WHERE sepa_metadata IS NOT NULL
        AND sepa_metadata != '{}'
        AND sepa_metadata != 'null'
    SQL

    invoices.each do |row|
      meta = JSON.parse(row["sepa_metadata"].to_s)
      next unless meta.is_a?(Hash) && meta["iban"].present? && meta["mandate_id"].present?

      normalized_iban = meta["iban"].to_s.gsub(/\s/, "").upcase
      sepa_debtor_name = meta["name"].to_s.strip.presence || member_debtor_name(row["member_id"]) || "DELETED"
      key = [ row["member_id"].to_i, normalized_iban, meta["mandate_id"].to_s, meta["mandate_signed_on"].to_s ]

      unless mandate_key_to_id[key]
        created_at = row["created_at"].presence || now.to_s
        mandate_key_to_id[key] = find_or_insert_mandate(
          member_id: row["member_id"],
          iban: normalized_iban,
          umr: meta["mandate_id"],
          signed_on: meta["mandate_signed_on"],
          source: "admin-legacy",
          created_at: created_at)
      end

      connection.execute(
        "UPDATE invoices SET sepa_mandate_id = #{mandate_key_to_id[key]}, " \
        "sepa_debtor_name = #{connection.quote(sepa_debtor_name)} " \
        "WHERE id = #{row['id']}")
    end

    # --- Step B -------------------------------------------------------
    # Create a SEPAMandate for each member whose current (iban, umr,
    # signed_on) tuple is not already covered by an invoice mandate above.
    # This captures members who have SEPA data but no invoices yet, or
    # whose IBAN was updated after the last invoice was created.
    members = connection.select_all(<<~SQL)
      SELECT id, iban, sepa_mandate_id, sepa_mandate_signed_on, updated_at, created_at
      FROM members
      WHERE iban IS NOT NULL AND iban != ''
        AND sepa_mandate_id IS NOT NULL AND sepa_mandate_id != ''
    SQL

    members.each do |row|
      next unless row["sepa_mandate_signed_on"].present?

      normalized_iban = row["iban"].to_s.gsub(/\s/, "").upcase
      key = [ row["id"].to_i, normalized_iban, row["sepa_mandate_id"].to_s, row["sepa_mandate_signed_on"].to_s ]
      next if mandate_key_to_id[key]

      created_at = row["updated_at"].presence || row["created_at"].presence || now.to_s
      find_or_insert_mandate(
        member_id: row["id"],
        iban: normalized_iban,
        umr: row["sepa_mandate_id"],
        signed_on: row["sepa_mandate_signed_on"].to_s,
        source: "admin-legacy",
        created_at: created_at)
    end

    # --- Preserve disabled members ------------------------------------
    # Reconstructed historical mandates must not reactivate members whose
    # live member-level SEPA fields were already cleared before migration.
    connection.execute(<<~SQL)
      UPDATE members
      SET sepa_disabled_at = #{connection.quote(now)}
      WHERE sepa_disabled_at IS NULL
        AND EXISTS (
          SELECT 1
          FROM sepa_mandates
          WHERE sepa_mandates.member_id = members.id
        )
        AND NOT (
          iban IS NOT NULL AND iban != ''
          AND sepa_mandate_id IS NOT NULL AND sepa_mandate_id != ''
          AND sepa_mandate_signed_on IS NOT NULL
        )
    SQL

    # --- Drop obsolete columns ----------------------------------------
    remove_column :invoices, :sepa_metadata
    remove_column :members, :iban
    remove_column :members, :sepa_mandate_id
    remove_column :members, :sepa_mandate_signed_on
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def member_debtor_name(member_id)
    connection.select_value(<<~SQL).to_s.strip.presence
      SELECT COALESCE(NULLIF(TRIM(billing_name), ''), NULLIF(TRIM(name), ''))
      FROM members
      WHERE id = #{connection.quote(member_id)}
      LIMIT 1
    SQL
  end

  # Finds an existing mandate or inserts a new one, using the migration
  # connection directly (bypassing ApplicationRecord) so it respects the
  # current Tenant context. Returns the id of the found or inserted row.
  def find_or_insert_mandate(member_id:, iban:, umr:, signed_on:, source:, created_at:)
    existing_id = connection.select_value(<<~SQL)
      SELECT id FROM sepa_mandates
      WHERE member_id = #{connection.quote(member_id)}
        AND iban = #{connection.quote(iban)}
        AND umr = #{connection.quote(umr)}
        AND signed_on = #{connection.quote(signed_on.to_s)}
      LIMIT 1
    SQL
    return existing_id if existing_id

    connection.insert(<<~SQL)
      INSERT INTO sepa_mandates (member_id, iban, umr, signed_on, source, created_at)
      VALUES (
        #{connection.quote(member_id)},
        #{connection.quote(iban)},
        #{connection.quote(umr)},
        #{connection.quote(signed_on.to_s)},
        #{connection.quote(source)},
        #{connection.quote(created_at.to_s)}
      )
    SQL
  end
end
