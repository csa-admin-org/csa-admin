# frozen_string_literal: true

module BasketContentsHelper
  def build_basket_content(attrs)
    BasketContent.new({
      product: basket_content_products(:carrots),
      delivery: deliveries(:monday_1),
      depots: Depot.all,
      quantity: 100,
      unit: "pc"
    }.merge(attrs))
  end

  def create_basket_content(attrs)
    build_basket_content(attrs).tap(&:save!)
  end
end
