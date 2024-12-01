# frozen_string_literal: true

class AddNewsletterDeliveriesUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :newsletter_deliveries, [ :newsletter_id, :member_id, :email ], unique: true
  end
end
