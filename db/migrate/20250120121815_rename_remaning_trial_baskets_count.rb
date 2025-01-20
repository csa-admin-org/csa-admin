# frozen_string_literal: true

class RenameRemaningTrialBasketsCount < ActiveRecord::Migration[8.0]
  def change
    rename_column :memberships, :remaning_trial_baskets_count, :remaining_trial_baskets_count
  end
end
