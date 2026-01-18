# frozen_string_literal: true

class RemoveMinimumGapInDaysFromDeliveryCycles < ActiveRecord::Migration[8.1]
  def change
    remove_column :delivery_cycles, :minimum_gap_in_days, :integer
    remove_column :delivery_cycle_periods, :minimum_gap_in_days, :integer
  end
end
