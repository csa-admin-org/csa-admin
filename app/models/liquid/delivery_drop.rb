class Liquid::DeliveryDrop < Liquid::Drop
  def initialize(delivery)
    @delivery = delivery
  end

  def date
    I18n.l(@delivery.date)
  end
end
