# frozen_string_literal: true

class AddTrialBasketsCountToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :trial_baskets_count, :integer
  end
end

# Tenant.switch_each do
#   count = Current.org.trial_baskets_count
#   Member.update_all(trial_baskets_count: count)
# end
