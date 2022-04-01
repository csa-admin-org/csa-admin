class RemoveBasketsContentsUniqueIndex < ActiveRecord::Migration[7.0]
  def change
    remove_index :basket_contents, column: [:vegetable_id, :delivery_id], unique: true
  end
end
