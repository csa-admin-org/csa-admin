# frozen_string_literal: true

class RenameBasketPriceToBasketSizePrice < ActiveRecord::Migration[8.1]
  def change
    rename_column :baskets, :basket_price, :basket_size_price
    rename_column :memberships, :basket_price, :basket_size_price

    # Update Liquid templates that reference the old basket_price variable
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE organizations
          SET basket_price_extra_dynamic_pricing = REPLACE(basket_price_extra_dynamic_pricing, 'basket_price', 'basket_size_price')
          WHERE basket_price_extra_dynamic_pricing IS NOT NULL
          AND basket_price_extra_dynamic_pricing LIKE '%basket_price%'
        SQL
      end

      dir.down do
        execute <<-SQL
          UPDATE organizations
          SET basket_price_extra_dynamic_pricing = REPLACE(basket_price_extra_dynamic_pricing, 'basket_size_price', 'basket_price')
          WHERE basket_price_extra_dynamic_pricing IS NOT NULL
          AND basket_price_extra_dynamic_pricing LIKE '%basket_size_price%'
        SQL
      end
    end
  end
end
