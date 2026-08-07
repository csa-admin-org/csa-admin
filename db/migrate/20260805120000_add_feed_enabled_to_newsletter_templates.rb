# frozen_string_literal: true

class AddFeedEnabledToNewsletterTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :newsletter_templates, :feed_enabled, :boolean, default: false, null: false
  end
end
