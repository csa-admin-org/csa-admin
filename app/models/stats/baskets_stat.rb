class Stats::BasketsStat < Stats::BaseStat
  def self.all
    [new(Date.current.year - 1), new(Date.current.year)]
  end

  def data
    basket_sizes =
      memberships(includes: [baskets: :basket_size])
        .flat_map { |m| m.baskets.map { |b| b.basket_size.name } }
    stats = Hash.new(0)
    basket_sizes.each { |bn| stats[bn] += 1 }
    stats.sort_by { |_k, v| -1 * v }.to_h
  end
end
