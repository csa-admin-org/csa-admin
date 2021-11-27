class AddVisibleToBasketSizes < ActiveRecord::Migration[6.1]
  def change
    add_column :basket_sizes, :visible, :boolean, null: false, default: true
    add_index :basket_sizes, :visible
  end
end
