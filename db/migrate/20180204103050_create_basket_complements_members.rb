class CreateBasketComplementsMembers < ActiveRecord::Migration[5.2]
  def change
    create_table :basket_complements_members do |t|
      t.references :basket_complement, null: false, index: false
      t.references :member, null: false, index: false
    end
    add_index :basket_complements_members, [ :basket_complement_id, :member_id ], unique: true, name: 'basket_complements_members_unique_index'
  end
end
