class RenameLostQuantityToSurplusQuantity < ActiveRecord::Migration[6.0]
  def change
    rename_column :basket_contents, :lost_quantity, :surplus_quantity
  end
end
