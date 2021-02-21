class ChangeBasketComplementsMembers < ActiveRecord::Migration[6.1]
  def change
    rename_table :basket_complements_members, :members_basket_complements
    add_column :members_basket_complements, :quantity, :integer, default: 1, null: false
    add_timestamps :members_basket_complements, null: true
    rename_index :members_basket_complements, 'basket_complements_members_unique_index', 'members_basket_complements_unique_index'
  end
end
