class RemoveDeliveryCyclesVisible < ActiveRecord::Migration[7.1]
  def change
    remove_column :delivery_cycles, :visible, :boolean, default: false, null: false
  end
end
