# frozen_string_literal: true

class AddTrialBasketsCountToMemberships < ActiveRecord::Migration[7.2]
  def change
    add_column :memberships, :trial_baskets_count, :integer, default: 0

    up_only do
      Membership.find_each(&:update_baskets_counts!)
    end
  end
end
