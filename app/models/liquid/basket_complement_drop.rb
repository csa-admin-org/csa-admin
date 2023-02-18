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
    helpers.basket_complements_description(@config, text_only: true)
  end

  private

  def helpers
    ApplicationController.helpers
  end
end
