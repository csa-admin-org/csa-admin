# frozen_string_literal: true

module BasketContentsHelper
  def build_basket_content(attrs)
    unit = attrs[:unit] || "pc"
    default_product = unit == "kg" ? basket_content_products(:carrots) : basket_content_products(:cucumbers)
    BasketContent.new({
      product: default_product,
      delivery: deliveries(:monday_1),
      depots: Depot.all,
      basket_size_ids_quantities: { small_id => 1, medium_id => 1 }
    }.merge(attrs))
  end

  def create_basket_content(attrs)
    build_basket_content(attrs).tap(&:save!)
  end
end
