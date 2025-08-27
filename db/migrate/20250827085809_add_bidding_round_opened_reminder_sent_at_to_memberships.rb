# frozen_string_literal: true

class AddBiddingRoundOpenedReminderSentAtToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :bidding_round_opened_reminder_sent_at, :datetime
  end
end
