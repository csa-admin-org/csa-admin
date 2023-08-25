class AddMinimumGapInDaysToDeliveriesCycles < ActiveRecord::Migration[7.0]
  def change
    add_column :deliveries_cycles, :minimum_gap_in_days, :integer
  end
end
