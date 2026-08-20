# frozen_string_literal: true

class Liquid::BasketContentDrop < Liquid::Drop
  include BasketContentsHelper

  private(*BasketContentsHelper.public_instance_methods)
  private(*NumbersHelper.public_instance_methods)
  private(*ActionView::Helpers::NumberHelper.instance_methods)
  private(*ActiveSupport::NumberHelper.instance_methods)

  def initialize(basket, basket_content)
    @basket = basket
    @basket_content = basket_content
    @quantity = @basket_content.basket_quantity(@basket.basket_size_id).to_f
  end

  def product
    @basket_content.product.name
  end

  def product_url
    @basket_content.product.url
  end

  def quantity
    display_quantity(@quantity, @basket_content.unit)
  end

  def unit
    @basket_content.unit
  end

  def price
    display_price(@basket_content.unit_price, @quantity)
  end

  def unit_price
    return unless @basket_content.unit_price.present?

    I18n.t("units.#{@basket_content.unit}_quantity", quantity: "#{cur(@basket_content.unit_price)}/")
  end
end
