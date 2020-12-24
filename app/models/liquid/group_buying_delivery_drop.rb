class Liquid::GroupBuyingDeliveryDrop < Liquid::Drop
  def initialize(delivery)
    @delivery = delivery
  end

  def id
    @delivery.id
  end

  def date
    I18n.l(@delivery.date)
  end
end
