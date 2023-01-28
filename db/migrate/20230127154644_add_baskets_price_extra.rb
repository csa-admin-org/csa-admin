class AddBasketsPriceExtra < ActiveRecord::Migration[7.0]
  def up
    add_column :baskets, :price_extra, :decimal, precision: 8, scale: 3, null: false, default: 0

    Basket.includes(:membership).find_each do |b|
      b.update_column(:price_extra, b.send(:calculate_price_extra))
    end
  end

  def down
    remove_column :baskets, :price_extra
  end
end
