# frozen_string_literal: true

# Phase 2d: Atomic migration of newsletter delivery data from the legacy
# `newsletter_deliveries` table into the unified `mail_deliveries` +
# `mail_delivery_emails` tables, followed by dropping the old table.
#
# Strategy:
# - Add a temporary `_legacy_newsletter_id` column to `mail_deliveries`
#   for fast indexed joins (avoids slow json_extract joins).
# - Bulk INSERT into `mail_deliveries` by grouping legacy rows on
#   [newsletter_id, member_id] — one parent per member per newsletter.
# - Bulk INSERT into `mail_delivery_emails` by joining back to the
#   newly-created parents — one child per original legacy row.
#   Rows with NULL email are excluded (members with no email address).
# - Recompute `state` on each MailDelivery from its Email children.
# - MailDeliveries with no Email children (no-email members) get
#   state "not_delivered" as trace-only records.
# - Drop newsletter_deliveries after successful backfill.
#
# Polymorphic mapping:
#   mailable_type = 'Newsletter'
#   mailable_ids  = json_array(newsletter_id)
#   action        = 'newsletter'
#
# State mapping from legacy:
#   'sent'    → 'delivered'
#   'ignored' → 'suppressed' (when email present)
#   others    → kept as-is
class MigrateNewsletterDeliveriesToMailDeliveries < ActiveRecord::Migration[8.1]
  def up
    # Temporary column for fast joins — avoids json_extract on every row.
    add_column :mail_deliveries, :_legacy_newsletter_id, :integer

    # Step 1: Bulk-insert one MailDelivery per (newsletter_id, member_id) group.
    # Use the first processed row (or earliest row) as the canonical source
    # for subject/content via a window function.
    # State defaults to 'processing' and will be recomputed in step 3.
    execute(<<~SQL)
      INSERT INTO mail_deliveries
        (mailable_type, mailable_ids, action, member_id, _legacy_newsletter_id,
         state, subject, content, created_at, updated_at)
      SELECT
        'Newsletter', json_array(newsletter_id), 'newsletter', member_id, newsletter_id,
        'processing', subject, content, created_at, updated_at
      FROM (
        SELECT
          newsletter_id,
          member_id,
          subject,
          content,
          processed_at,
          created_at,
          updated_at,
          ROW_NUMBER() OVER (
            PARTITION BY newsletter_id, member_id
            ORDER BY
              CASE WHEN processed_at IS NOT NULL THEN 0 ELSE 1 END,
              created_at ASC
          ) AS rn
        FROM newsletter_deliveries
        WHERE newsletter_id IS NOT NULL
      )
      WHERE rn = 1
    SQL

    # Temporary index for fast join in step 2.
    add_index :mail_deliveries, [ :_legacy_newsletter_id, :member_id ],
      name: "idx_tmp_legacy_newsletter_member"

    # Step 2: Bulk-insert one MailDelivery::Email per legacy row, joining
    # back to the parent mail_deliveries created in step 1.
    # Rows with NULL email are excluded — those members had no email address
    # and their MailDelivery will be set to "not_delivered" in step 3.
    execute(<<~SQL)
      INSERT INTO mail_delivery_emails
        (mail_delivery_id, email, state, processed_at,
         delivered_at, bounced_at,
         bounce_type, bounce_type_code, bounce_description,
         postmark_message_id, postmark_details,
         email_suppression_ids, email_suppression_reasons,
         created_at, updated_at)
      SELECT
        md.id,
        nd.email,
        CASE nd.state WHEN 'sent' THEN 'delivered' WHEN 'ignored' THEN 'suppressed' ELSE nd.state END,
        nd.processed_at,
        nd.delivered_at,
        nd.bounced_at,
        nd.bounce_type,
        nd.bounce_type_code,
        nd.bounce_description,
        nd.postmark_message_id,
        nd.postmark_details,
        COALESCE(nd.email_suppression_ids, '[]'),
        COALESCE(nd.email_suppression_reasons, '[]'),
        nd.created_at,
        nd.updated_at
      FROM newsletter_deliveries nd
      INNER JOIN mail_deliveries md
        ON md._legacy_newsletter_id = nd.newsletter_id
        AND md.member_id = nd.member_id
      WHERE nd.newsletter_id IS NOT NULL
        AND nd.email IS NOT NULL
    SQL

    # Step 3: Recompute state on each MailDelivery from its Email children.

    # 3a: Drafts — newsletter not yet sent → MailDelivery state = 'draft'
    execute <<~SQL
      UPDATE mail_deliveries SET state = 'draft'
      WHERE state = 'processing'
        AND _legacy_newsletter_id IN (
          SELECT id FROM newsletters WHERE sent_at IS NULL
        )
    SQL

    # Delete all Email children of draft MailDeliveries (drafts have no children going forward)
    execute <<~SQL
      DELETE FROM mail_delivery_emails
      WHERE mail_delivery_id IN (
        SELECT id FROM mail_deliveries WHERE state = 'draft'
      )
    SQL

    # 3b: Compute final state for all remaining 'processing' deliveries
    # in a single UPDATE with CASE expression.
    execute <<~SQL
      UPDATE mail_deliveries SET state = (
        CASE
          WHEN NOT EXISTS (
            SELECT 1 FROM mail_delivery_emails WHERE mail_delivery_id = mail_deliveries.id
          ) THEN 'not_delivered'
          WHEN NOT EXISTS (
            SELECT 1 FROM mail_delivery_emails
            WHERE mail_delivery_id = mail_deliveries.id AND state != 'delivered'
          ) THEN 'delivered'
          WHEN NOT EXISTS (
            SELECT 1 FROM mail_delivery_emails
            WHERE mail_delivery_id = mail_deliveries.id AND state NOT IN ('suppressed', 'bounced')
          ) THEN 'not_delivered'
          WHEN EXISTS (
            SELECT 1 FROM mail_delivery_emails
            WHERE mail_delivery_id = mail_deliveries.id AND state = 'delivered'
          ) AND EXISTS (
            SELECT 1 FROM mail_delivery_emails
            WHERE mail_delivery_id = mail_deliveries.id AND state IN ('suppressed', 'bounced')
          ) THEN 'partially_delivered'
          ELSE 'processing'
        END
      )
      WHERE state = 'processing'
    SQL

    # Clean up: explicitly drop temporary index then column.
    # SQLite rebuilds composite indexes as single-column on ALTER TABLE,
    # so we must drop the index first to avoid leaving a partial index behind.
    remove_index :mail_deliveries, name: "idx_tmp_legacy_newsletter_member"
    remove_column :mail_deliveries, :_legacy_newsletter_id

    drop_table :newsletter_deliveries
  end

  def down
    create_table :newsletter_deliveries do |t|
      t.string :bounce_description
      t.string :bounce_type
      t.integer :bounce_type_code
      t.text :content
      t.datetime :delivered_at
      t.string :email
      t.json :email_suppression_ids, default: [], null: false
      t.json :email_suppression_reasons, default: [], null: false
      t.references :member, null: false, foreign_key: true
      t.references :newsletter, null: false, foreign_key: true
      t.string :postmark_details
      t.string :postmark_message_id
      t.datetime :processed_at
      t.string :state, default: "processing", null: false
      t.string :subject
      t.timestamps
    end

    add_index :newsletter_deliveries,
      [ :newsletter_id, :member_id, :email ],
      unique: true,
      name: "idx_on_newsletter_id_member_id_email_00311dbc8c"
    add_index :newsletter_deliveries, :state

    add_check_constraint :newsletter_deliveries,
      "JSON_TYPE(email_suppression_ids) = 'array'",
      name: "newsletter_deliveries_email_suppression_ids_is_array"
    add_check_constraint :newsletter_deliveries,
      "JSON_TYPE(email_suppression_reasons) = 'array'",
      name: "newsletter_deliveries_email_suppression_reasons_is_array"

    # Reverse backfill: MailDelivery (Newsletter) → newsletter_deliveries
    # Email children map back to rows with email addresses.
    execute(<<~SQL)
      INSERT INTO newsletter_deliveries
        (newsletter_id, member_id, email, state,
         subject, content, processed_at,
         delivered_at, bounced_at,
         bounce_type, bounce_type_code, bounce_description,
         postmark_message_id, postmark_details,
         email_suppression_ids, email_suppression_reasons,
         created_at, updated_at)
      SELECT
        json_extract(md.mailable_ids, '$[0]'), md.member_id, mde.email, mde.state,
        md.subject, md.content, mde.processed_at,
        mde.delivered_at, mde.bounced_at,
        mde.bounce_type, mde.bounce_type_code, mde.bounce_description,
        mde.postmark_message_id, mde.postmark_details,
        mde.email_suppression_ids, mde.email_suppression_reasons,
        mde.created_at, mde.updated_at
      FROM mail_delivery_emails mde
      INNER JOIN mail_deliveries md ON md.id = mde.mail_delivery_id
      WHERE md.mailable_type = 'Newsletter'
    SQL

    # Reverse backfill: no-email members (not_delivered with no children)
    # become "ignored" rows with NULL email.
    execute(<<~SQL)
      INSERT INTO newsletter_deliveries
        (newsletter_id, member_id, email, state,
         subject, content,
         email_suppression_ids, email_suppression_reasons,
         created_at, updated_at)
      SELECT
        json_extract(md.mailable_ids, '$[0]'), md.member_id, NULL, 'ignored',
        md.subject, md.content,
        '[]', '[]',
        md.created_at, md.updated_at
      FROM mail_deliveries md
      WHERE md.mailable_type = 'Newsletter'
        AND md.state = 'not_delivered'
        AND NOT EXISTS (
          SELECT 1 FROM mail_delivery_emails WHERE mail_delivery_id = md.id
        )
    SQL

    # Remove backfilled newsletter records from the new tables
    execute(<<~SQL)
      DELETE FROM mail_delivery_emails
      WHERE mail_delivery_id IN (
        SELECT id FROM mail_deliveries WHERE mailable_type = 'Newsletter'
      )
    SQL

    execute("DELETE FROM mail_deliveries WHERE mailable_type = 'Newsletter'")
  end
end
