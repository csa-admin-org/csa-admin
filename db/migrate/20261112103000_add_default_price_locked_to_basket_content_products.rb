# frozen_string_literal: true

class AddDefaultPriceLockedToBasketContentProducts < ActiveRecord::Migration[8.2]
  def change
    add_column :basket_content_products, :default_price_locked, :boolean, default: false, null: false
  end
end
