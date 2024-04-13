class AddDiscardedAt < ActiveRecord::Migration[7.1]
  def change
    add_column :shop_product_variants, :discarded_at, :datetime
    add_index :shop_product_variants, :discarded_at

    add_column :shop_products, :discarded_at, :datetime
    add_index :shop_products, :discarded_at

    add_column :shop_producers, :discarded_at, :datetime
    add_index :shop_producers, :discarded_at

    add_column :shop_tags, :discarded_at, :datetime
    add_index :shop_tags, :discarded_at
  end
end
