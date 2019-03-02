class AddActivityPriceToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :activity_price, :decimal, precision: 8, scale: 2, default: 0, null: false
  end
end
