class Liquid::BasketSizeDrop < Liquid::Drop
  def initialize(basket_size)
    @basket_size = basket_size
  end

  def id
    @basket_size.id
  end

  def name
    @basket_size.name
  end
end
