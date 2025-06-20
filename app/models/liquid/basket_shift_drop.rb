# frozen_string_literal: true

class Liquid::BasketShiftDrop < Liquid::Drop
  def initialize(basket_shift)
    @basket_shift = basket_shift
  end

  def new_delivery_date
    I18n.l(@basket_shift.target_basket.delivery.date)
  end

  def old_delivery_date
    I18n.l(@basket_shift.source_basket.delivery.date)
  end

  def description
    @basket_shift.description(public_name: true)
  end
end
