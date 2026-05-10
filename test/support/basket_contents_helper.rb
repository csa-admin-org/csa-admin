# frozen_string_literal: true

module BasketContentsHelper
  def build_basket_content(attrs)
    BasketContent.new({
      product: basket_content_products(:carrots),
      delivery: deliveries(:monday_1),
      depots: Depot.all,
      unit: "pc",
      basket_size_ids_quantities: { small_id => 1, medium_id => 1 }
    }.merge(attrs))
  end

  def create_basket_content(attrs)
    build_basket_content(attrs).tap(&:save!)
  end
end
