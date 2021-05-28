class Liquid::AdminBasketDrop < Liquid::Drop
  def initialize(basket)
    @basket = basket
  end

  def member
    Liquid::MemberDrop.new(@basket.member)
  end

  def description
    @basket.description
  end
end
