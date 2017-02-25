class Stats::BasketsStat < Stats::BaseStat
  def self.all
    [new(2016), new(2017)]
  end

  def data
    baskets = memberships(includes: [:basket]).map { |m| m.basket.name }
    stats = Hash.new(0)
    baskets.each { |basket| stats[basket] += 1 }
    stats.sort_by { |_k, v| -1 * v }.to_h
  end
end
