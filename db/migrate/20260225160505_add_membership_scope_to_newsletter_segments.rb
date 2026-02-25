# frozen_string_literal: true

class AddMembershipScopeToNewsletterSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :newsletter_segments, :membership_scope, :string, default: "current_or_future", null: false
  end
end
