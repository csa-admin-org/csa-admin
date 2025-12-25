# frozen_string_literal: true

class AddMembershipTrialCancelationToAdminNotifications < ActiveRecord::Migration[8.1]
  def up
    Admin.where("EXISTS (SELECT 1 FROM json_each(notifications) WHERE json_each.value = ?)", "new_registration").find_each do |admin|
      admin.update_column(:notifications, admin.notifications + [ "membership_trial_cancelation" ])
    end
  end

  def down
    Admin.where("EXISTS (SELECT 1 FROM json_each(notifications) WHERE json_each.value = ?)", "membership_trial_cancelation").find_each do |admin|
      admin.update_column(:notifications, admin.notifications - [ "membership_trial_cancelation" ])
    end
  end
end
