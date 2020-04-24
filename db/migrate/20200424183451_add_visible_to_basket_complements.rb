class AddVisibleToBasketComplements < ActiveRecord::Migration[6.0]
  def change
    add_column :basket_complements, :visible, :boolean, null: false, default: true
    add_index :basket_complements, :visible
  end
end
