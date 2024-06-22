# frozen_string_literal: true

class NewsletterDeliveriesCleaning < ActiveRecord::Migration[7.1]
  def up
    remove_column :newsletter_deliveries, :emails
    remove_column :newsletter_deliveries, :suppressed_emails
  end
end
