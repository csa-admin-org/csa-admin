# frozen_string_literal: true

class MoveBasketComplementToShopProductVariants < ActiveRecord::Migration[8.1]
  def up
    add_reference :shop_product_variants, :basket_complement,
      foreign_key: true,
      index: { unique: true }

    invalid_product_ids = select_values(<<~SQL)
      SELECT shop_products.id
      FROM shop_products
      LEFT JOIN shop_product_variants
        ON shop_product_variants.product_id = shop_products.id
      WHERE shop_products.basket_complement_id IS NOT NULL
      GROUP BY shop_products.id
      HAVING COUNT(shop_product_variants.id) != 1
    SQL
    if invalid_product_ids.any?
      raise ActiveRecord::MigrationError,
        "Shop products linked to basket complements must have exactly one variant: #{invalid_product_ids.join(', ')}"
    end

    execute <<~SQL
      UPDATE shop_product_variants
      SET basket_complement_id = (
        SELECT shop_products.basket_complement_id
        FROM shop_products
        WHERE shop_products.id = shop_product_variants.product_id
      )
      WHERE product_id IN (
        SELECT id
        FROM shop_products
        WHERE basket_complement_id IS NOT NULL
      )
    SQL

    remove_reference :shop_products, :basket_complement,
      foreign_key: true,
      index: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "A product can now have variants linked to different basket complements"
  end
end
