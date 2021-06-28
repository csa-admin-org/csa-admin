class AddShopModels < ActiveRecord::Migration[6.1]
  def change
    create_table :shop_tags do |t|
      t.jsonb :names, default: {}, null: false
      t.string :emoji
    end

    create_table :shop_producers do |t|
      t.string :name, null: false
      t.string :website_url
    end

    create_table :shop_products do |t|
      t.references :producer, foreign_key: { to_table: :shop_producers }, index: true

      t.jsonb :names, default: {}, null: false
      t.boolean :available, default: true, null: false, index: true
    end

    create_table :shop_product_variants do |t|
      t.references :product, foreign_key: { to_table: :shop_products }, null: false, index: true

      t.jsonb :names, default: {}, null: false
      t.decimal :price, scale: 2, precision: 8, null: false
      t.decimal :weight_in_kg, scale: 2, precision: 8
      t.integer :stock
    end

    create_table :shop_products_tags, id: false do |t|
      t.references :product, foreign_key: { to_table: :shop_products }, null: false, index: false
      t.references :tag, foreign_key: { to_table: :shop_tags }, null: false, index: false
    end
    add_index :shop_products_tags, [:product_id, :tag_id], unique: true, name: 'index_shop_products_tags_unique'
  end
end
