class DeliveryCount
  include Singleton

  def initialize
    @deliveries = Delivery.all.to_a
  end

  def count(range)
    all(range).size
  end

  def first(range)
    all(range).first
  end

  def all(range)
    @deliveries.select do |d|
      d.date >= range.first && d.date <= range.last
    end
  end
end
