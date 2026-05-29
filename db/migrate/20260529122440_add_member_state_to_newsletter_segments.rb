# frozen_string_literal: true

class AddMemberStateToNewsletterSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :newsletter_segments, :member_state, :string
  end
end
