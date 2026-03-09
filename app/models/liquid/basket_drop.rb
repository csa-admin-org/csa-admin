# frozen_string_literal: true

class Liquid::BasketDrop < Liquid::Drop
  def initialize(basket)
    @basket = basket
  end

  def delivery
    if delivery = @basket.delivery
      Liquid::DeliveryDrop.new(delivery)
    end
  end

  def description
    helpers.basket_size_description(@basket, text_only: true)
  end

  def complements_description
    helpers.basket_complements_description(@basket.baskets_basket_complements, text_only: true)
  end

  def size
    if basket_size = @basket.basket_size
      Liquid::BasketSizeDrop.new(basket_size)
    end
  end

  def depot
    if depot = @basket.depot
      Liquid::DepotDrop.new(depot)
    end
  end

  def quantity
    @basket.quantity
  end

  def shifted
    return false unless Current.org.basket_shift_enabled?

    @basket.shifts_as_target.any?
  end

  def shifts
    return [] unless Current.org.basket_shift_enabled?

    @basket.shifts_as_target.includes(source_basket: :delivery, target_basket: :delivery).map { |shift|
      Liquid::BasketShiftDrop.new(shift)
    }
  end

  def contents
    @basket.contents.map { |bc|
      Liquid::BasketContentDrop.new(@basket, bc)
    }
  end

  def complements
    @basket.baskets_basket_complements.map { |bbc|
      Liquid::BasketComplementDrop.new(bbc)
    }
  end

  private

  def helpers
    ApplicationController.helpers
  end
end
