class Liquid::BasketContentDrop < Liquid::Drop

  def initialize(basket, basket_content)
    @basket = basket
    @basket_content = basket_content
    @quantity = @basket_content.basket_quantity(@basket.basket_size_id).to_f
  end

  def product
    @basket_content.product.name
  end

  def quantity
    helpers.display_quantity(@quantity, @basket_content.unit)
  end

  def unit
    @basket_content.unit
  end

  def price
    helpers.display_price(@basket_content.unit_price, @quantity)
  end

  def unit_price
    return unless @basket_content.unit_price.present?

    I18n.t("units.#{@basket_content.unit}_quantity", quantity: "#{helpers.cur(@basket_content.unit_price)}/")
  end

  private

  def helpers
    ApplicationController.helpers
  end
end
