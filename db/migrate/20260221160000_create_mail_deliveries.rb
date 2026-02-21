# frozen_string_literal: true

class CreateMailDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_deliveries do |t|
      t.string :mailable_type, null: false
      t.json :mailable_ids, null: false, default: []
      t.string :action, null: false
      t.references :member, null: false, foreign_key: true, index: true
      t.string :state, null: false, default: "processing"
      t.string :subject
      t.text :content
      t.timestamps
    end

    add_index :mail_deliveries, [ :mailable_type, :mailable_ids, :member_id ],
      name: "idx_mail_deliveries_on_mailable_member"
    add_index :mail_deliveries, [ :member_id, :created_at ],
      name: "idx_mail_deliveries_on_member_created"
    add_index :mail_deliveries, :state
    add_index :mail_deliveries, [ :mailable_type, :created_at ],
      name: "idx_mail_deliveries_on_mailable_type_created_at"

    add_check_constraint :mail_deliveries, "JSON_TYPE(mailable_ids) = 'array'",
      name: "mail_deliveries_mailable_ids_is_array"

    create_table :mail_delivery_emails do |t|
      t.references :mail_delivery, null: false, foreign_key: true, index: true
      t.string :email, null: false
      t.string :state, default: "processing", null: false
      t.datetime :processed_at
      t.datetime :delivered_at
      t.datetime :bounced_at
      t.string :bounce_type
      t.integer :bounce_type_code
      t.string :bounce_description
      t.string :postmark_message_id
      t.text :postmark_details
      t.json :email_suppression_ids, default: [], null: false
      t.json :email_suppression_reasons, default: [], null: false
      t.timestamps
    end

    add_index :mail_delivery_emails, [ :mail_delivery_id, :email ], unique: true,
      name: "idx_mail_delivery_emails_on_delivery_id_email"
    add_index :mail_delivery_emails, :state
    add_index :mail_delivery_emails, [ :mail_delivery_id, :state ],
      name: "idx_mail_delivery_emails_on_delivery_id_state"
    add_index :mail_delivery_emails, :postmark_message_id, unique: true,
      where: "postmark_message_id IS NOT NULL",
      name: "idx_mail_delivery_emails_on_postmark_message_id"

    add_check_constraint :mail_delivery_emails, "JSON_TYPE(email_suppression_ids) = 'array'",
      name: "mail_delivery_emails_email_suppression_ids_is_array"
    add_check_constraint :mail_delivery_emails, "JSON_TYPE(email_suppression_reasons) = 'array'",
      name: "mail_delivery_emails_email_suppression_reasons_is_array"
  end
end
