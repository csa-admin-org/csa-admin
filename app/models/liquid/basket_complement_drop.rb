class Liquid::BasketComplementDrop < Liquid::Drop
  def initialize(basket_complement)
    @config = basket_complement
    @basket_complement = basket_complement.basket_complement
  end

  def id
    @basket_complement.id
  end

  def quantity
    @config.quantity
  end

  def name
    @basket_complement.public_name
  end

  def description
    @config.description(public_name: true)
  end

  private

  def helpers
    ApplicationController.helpers
  end
end
