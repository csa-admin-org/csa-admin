# frozen_string_literal: true

class AddApplyBasketSizePricePercentageToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :apply_basket_size_price_percentage, :boolean, default: true, null: false
  end
end
