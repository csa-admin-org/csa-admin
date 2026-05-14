# frozen_string_literal: true

class MoveUnitToBasketContentProducts < ActiveRecord::Migration[8.1]
  def up
    rename_column :basket_content_products, :default_unit, :unit

    # Duplicate products that have basket contents with mixed units.
    # For each such product, the original keeps the unit of its latest basket content,
    # and a new product is created for the other unit, with basket contents reassigned.
    duplicate_mixed_unit_products

    execute "UPDATE basket_content_products SET unit = 'kg' WHERE unit IS NULL OR unit = ''"
    change_column_null :basket_content_products, :unit, false

    rename_column :basket_content_products, :default_unit_price, :default_price

    # Sync all products with their latest basket content (price + quantities)
    sync_all_products
  end

  def down
    rename_column :basket_content_products, :default_price, :default_unit_price
    change_column_null :basket_content_products, :unit, true
    rename_column :basket_content_products, :unit, :default_unit
  end

  private

  def duplicate_mixed_unit_products
    mixed_product_ids = connection.select_values(<<~SQL)
      SELECT product_id FROM basket_contents
      GROUP BY product_id
      HAVING COUNT(DISTINCT unit) > 1
    SQL

    return if mixed_product_ids.empty?

    mixed_product_ids.each do |product_id|
      # Determine which unit the product keeps (from its latest basket content by delivery date)
      primary_unit = connection.select_value(<<~SQL)
        SELECT bc.unit
        FROM basket_contents bc
        INNER JOIN deliveries d ON d.id = bc.delivery_id
        WHERE bc.product_id = #{product_id.to_i}
        ORDER BY d.date DESC
        LIMIT 1
      SQL

      other_unit = primary_unit == "kg" ? "pc" : "kg"

      # Set the original product's unit
      connection.execute(<<~SQL)
        UPDATE basket_content_products SET unit = #{connection.quote(primary_unit)} WHERE id = #{product_id.to_i}
      SQL

      # Create a duplicate product for the other unit (same name, different unit)
      product_data = connection.select_one(<<~SQL)
        SELECT names, url, default_unit_price, default_basket_quantities
        FROM basket_content_products WHERE id = #{product_id.to_i}
      SQL

      connection.execute(<<~SQL)
        INSERT INTO basket_content_products (names, url, unit, default_unit_price, default_basket_quantities, created_at, updated_at)
        VALUES (
          #{connection.quote(product_data["names"])},
          #{connection.quote(product_data["url"])},
          #{connection.quote(other_unit)},
          NULL,
          '{}',
          datetime('now'),
          datetime('now')
        )
      SQL

      new_product_id = connection.select_value("SELECT last_insert_rowid()")

      # Reassign basket contents with the other unit to the new product
      connection.execute(<<~SQL)
        UPDATE basket_contents
        SET product_id = #{new_product_id.to_i}
        WHERE product_id = #{product_id.to_i} AND unit = #{connection.quote(other_unit)}
      SQL
    end
  end

  def sync_all_products
    BasketContent::Product.reset_column_information
    BasketContent::Product.find_each(&:sync_latest_basket_content!)
  end
end
