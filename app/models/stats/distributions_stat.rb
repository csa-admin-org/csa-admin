class Stats::DistributionsStat < Stats::BaseStat
  def self.all
    [new(Current.fy_year - 1), new(Current.fy_year)]
  end

  def data
    distributions =
      memberships(includes: [baskets: :distribution])
        .flat_map { |m| m.baskets.map { |b| b.distribution.name } }
    stats = Hash.new(0)
    distributions.each { |distribution| stats[distribution] += 1 }
    stats.delete('Domicile')
    stats.sort_by { |_k, v| -1 * v }.to_h
  end
end
