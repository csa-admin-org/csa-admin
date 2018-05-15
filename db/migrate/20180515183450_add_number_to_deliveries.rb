class AddNumberToDeliveries < ActiveRecord::Migration[5.2]
  def change
    add_column :deliveries, :number, :integer, null: false, default: 0
  end
end
