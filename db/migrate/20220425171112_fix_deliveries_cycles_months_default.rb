class FixDeliveriesCyclesMonthsDefault < ActiveRecord::Migration[7.0]
  def change
    change_column_default :deliveries_cycles, :months, from: Array(0..12), to: Array(1..12)
  end
end
