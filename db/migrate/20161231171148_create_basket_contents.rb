class CreateBasketContents < ActiveRecord::Migration[5.0]
  def change
    create_table :basket_contents do |t|
      t.references :delivery, foreign_key: true, null: false, index: true
      t.references :vegetable, foreign_key: true, null: false
      t.decimal :quantity, precision: 8, scale: 2, null: false
      t.string :unit, null: false
      t.decimal :small_basket_quantity, precision: 8, scale: 2, null: false, default: 0
      t.decimal :big_basket_quantity, precision: 8, scale: 2, null: false, default: 0
      t.decimal :lost_quantity, precision: 8, scale: 2, null: false, default: 0
      t.integer :small_baskets_count, null: false, default: 0
      t.integer :big_baskets_count, null: false, default: 0

      t.timestamps
    end
    add_index :basket_contents, [ :vegetable_id, :delivery_id ], unique: true

    create_table :basket_contents_distributions, id: false do |t|
      t.references :basket_content, foreign_key: true, null: false, index: true
      t.references :distribution, foreign_key: true, null: false, index: true
    end
    add_index :basket_contents_distributions, [ :basket_content_id, :distribution_id ], unique: true, name: 'index_basket_contents_distributions_unique'
  end
end
