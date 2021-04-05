class AddBasketPriceExtraSettingsToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :basket_price_extras, :decimal, precision: 8, scale: 2, array: true, default: [], null: false
    add_column :acps, :basket_price_extra_titles, :jsonb, default: {}, null: false
    add_column :acps, :basket_price_extra_texts, :jsonb, default: {}, null: false
    add_column :acps, :basket_price_extra_labels, :jsonb, default: {}, null: false
    add_column :acps, :basket_price_extra_label_details, :jsonb, default: {}, null: false
  end
end
