# frozen_string_literal: true

module ShopHelper
  def build_shop_order(attrs = {})
    Shop::Order.new({
      member: members(:jane),
      delivery: deliveries(:thursday_1),
      state: "pending",
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_500).id,
          quantity: 1
        }
      }
    }.merge(attrs))
  end


  def create_shop_order(attrs = {})
    build_shop_order(attrs).tap(&:save!)
  end
end
