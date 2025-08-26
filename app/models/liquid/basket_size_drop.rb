# frozen_string_literal: true

class Liquid::BasketSizeDrop < Liquid::Drop
  include NumbersHelper

  private(*NumbersHelper.public_instance_methods)
  private(*ActiveSupport::NumberHelper.instance_methods)

  def initialize(basket_size)
    @basket_size = basket_size
  end

  def id
    @basket_size.id
  end

  def name
    @basket_size.public_name
  end

  def price
    cur(@basket_size.price)
  end
end
