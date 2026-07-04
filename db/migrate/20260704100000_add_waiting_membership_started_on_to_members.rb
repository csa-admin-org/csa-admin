# frozen_string_literal: true

class AddWaitingMembershipStartedOnToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :waiting_membership_started_on, :date
  end
end
