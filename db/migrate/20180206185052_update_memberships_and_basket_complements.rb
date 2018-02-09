class UpdateMembershipsAndBasketComplements < ActiveRecord::Migration[5.2]
  def change
    drop_table :basket_complements_memberships

    create_table :memberships_basket_complements do |t|
      t.references :basket_complement, null: false, index: false
      t.references :membership, null: false, index: false
      t.decimal :price, scale: 3, precision: 8, null: false
      t.integer :quantity, default: 1, null: false
      t.timestamps
    end
    add_index :memberships_basket_complements, [:basket_complement_id, :membership_id], unique: true, name: 'memberships_basket_complements_unique_index'

    add_reference :memberships, :basket_size
    add_reference :memberships, :distribution
    add_column :memberships, :basket_quantity, :integer, default: 1, null: false
    add_column :memberships, :basket_price, :decimal, scale: 3, precision: 8
    add_column :memberships, :distribution_price, :decimal, scale: 3, precision: 8
  end
end
