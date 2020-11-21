class Liquid::BasketComplementDrop < Liquid::Drop
  def initialize(basket_complement)
    @basket_complement = basket_complement
  end

  def id
    @basket_complement.id
  end

  def name
    @basket_complement.name
  end
end
