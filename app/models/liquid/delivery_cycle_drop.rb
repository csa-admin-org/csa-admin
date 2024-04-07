class Liquid::DeliveryCycleDrop < Liquid::Drop
  def initialize(delivery_cycle)
    @delivery_cycle = delivery_cycle
  end

  def id
    @delivery_cycle.id
  end

  def name
    @delivery_cycle.public_name
  end
end
