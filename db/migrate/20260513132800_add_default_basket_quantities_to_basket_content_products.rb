# frozen_string_literal: true

class AddDefaultBasketQuantitiesToBasketContentProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :basket_content_products, :default_basket_quantities, :json, default: {}, null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE basket_content_products
          SET default_unit = (
                SELECT bc.unit
                FROM basket_contents bc
                INNER JOIN deliveries d ON d.id = bc.delivery_id
                WHERE bc.product_id = basket_content_products.id
                ORDER BY d.date DESC
                LIMIT 1
              ),
              default_unit_price = (
                SELECT bc.unit_price
                FROM basket_contents bc
                INNER JOIN deliveries d ON d.id = bc.delivery_id
                WHERE bc.product_id = basket_content_products.id
                ORDER BY d.date DESC
                LIMIT 1
              ),
              default_basket_quantities = (
                SELECT bc.basket_quantities
                FROM basket_contents bc
                INNER JOIN deliveries d ON d.id = bc.delivery_id
                WHERE bc.product_id = basket_content_products.id
                ORDER BY d.date DESC
                LIMIT 1
              )
          WHERE EXISTS (
            SELECT 1 FROM basket_contents
            WHERE basket_contents.product_id = basket_content_products.id
          )
        SQL

        # Convert kg quantities from decimals to grams (display format)
        convert_quantities_to_display_format
      end
    end
  end

  private

  def convert_quantities_to_display_format
    rows = connection.select_all(<<~SQL)
      SELECT id, default_unit, default_basket_quantities
      FROM basket_content_products
      WHERE default_unit = 'kg' AND default_basket_quantities != '{}'
    SQL

    rows.each do |row|
      quantities = JSON.parse(row["default_basket_quantities"])
      display_quantities = quantities.transform_values { |v| (BigDecimal(v.to_s) * 1000).round }
      connection.execute(<<~SQL)
        UPDATE basket_content_products
        SET default_basket_quantities = #{connection.quote(display_quantities.to_json)}
        WHERE id = #{row["id"].to_i}
      SQL
    end
  end
end
