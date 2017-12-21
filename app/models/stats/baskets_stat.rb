class Stats::BasketsStat < Stats::BaseStat
  def self.all
    [new(2016), new(2017)]
  end

  def data
    basket_names = memberships(includes: [:basket_size]).map { |m| m.basket_size.name }
    stats = Hash.new(0)
    basket_names.each { |basket_name| stats[basket_name] += 1 }
    stats.sort_by { |_k, v| -1 * v }.to_h
  end
end
