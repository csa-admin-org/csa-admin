# frozen_string_literal: true

class AddBasketIdIndexToBasketsBasketComplements < ActiveRecord::Migration[8.1]
  def change
    add_index :baskets_basket_complements, :basket_id
  end
end
