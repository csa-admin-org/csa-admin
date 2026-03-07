# frozen_string_literal: true

class AddDemoFollowUpSentAtToAdmins < ActiveRecord::Migration[8.1]
  def change
    add_column :admins, :demo_follow_up_sent_at, :datetime
  end
end
