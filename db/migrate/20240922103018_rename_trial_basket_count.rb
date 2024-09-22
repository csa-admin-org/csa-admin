# frozen_string_literal: true

class RenameTrialBasketCount < ActiveRecord::Migration[7.2]
  def change
    rename_column :organizations, :trial_basket_count, :trial_baskets_count
  end
end
