# frozen_string_literal: true

class Liquid::BasketDrop < Liquid::Drop
  def initialize(basket)
    @basket = basket
  end

  def delivery
    Liquid::DeliveryDrop.new(@basket.delivery)
  end

  def description
    helpers.basket_size_description(@basket, text_only: true)
  end

  def complements_description
    helpers.basket_complements_description(@basket.baskets_basket_complements, text_only: true)
  end

  def size
    Liquid::BasketSizeDrop.new(@basket.basket_size)
  end

  def depot
    Liquid::DepotDrop.new(@basket.depot)
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
    @basket.delivery.basket_contents.includes(:product).select { |bc|
      bc.depot_ids.include?(@basket.depot_id)
        && bc.basket_quantity(@basket.basket_size)&.positive?
    }.sort_by { |bc|
      bc.product.name
    }.map { |bc|
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
