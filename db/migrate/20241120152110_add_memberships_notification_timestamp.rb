# frozen_string_literal: true

class AddMembershipsNotificationTimestamp < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :initial_basket_sent_at, :datetime
    add_column :members, :final_basket_sent_at, :datetime

    add_column :memberships, :first_basket_sent_at, :datetime
    add_column :memberships, :last_basket_sent_at, :datetime
  end
end
