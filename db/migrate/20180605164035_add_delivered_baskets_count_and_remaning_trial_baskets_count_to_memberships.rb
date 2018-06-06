class AddDeliveredBasketsCountAndRemaningTrialBasketsCountToMemberships < ActiveRecord::Migration[5.2]
  def change
    add_column :memberships, :delivered_baskets_count, :integer, default: 0, null: false
    add_column :memberships, :remaning_trial_baskets_count, :integer, default: 0, null: false

    Membership.find_each(&:update_baskets_counts!)
  end
end
