# frozen_string_literal: true

class NewsletterDeliveriesPostmarkAttrs < ActiveRecord::Migration[7.1]
  def change
    add_column :newsletter_deliveries, :postmark_message_id, :string
    add_column :newsletter_deliveries, :postmark_details, :text
    add_column :newsletter_deliveries, :bounced_at, :datetime
    add_column :newsletter_deliveries, :bounce_type, :string
    add_column :newsletter_deliveries, :bounce_type_code, :integer
    add_column :newsletter_deliveries, :bounce_description, :string
  end
end
