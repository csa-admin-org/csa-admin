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

  def contents
    @basket.delivery.basket_contents.includes(:product).select { |bc|
      bc.depot_ids.include?(@basket.depot_id)
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
