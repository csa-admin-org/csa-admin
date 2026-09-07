# frozen_string_literal: true

class AddMemberNewsletterListIndexToMailDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_index :mail_deliveries, [ :member_id, :mailable_type, :created_at ],
      name: "idx_mail_deliveries_on_member_mailable_created"
  end
end
