class AddBasketContentProductsUrl < ActiveRecord::Migration[7.0]
  def change
    add_column :basket_content_products, :url, :string
  end
end
