class Stats::DistributionsStat < Stats::BaseStat
  def self.all
    [new(Date.today.year - 1), new(Date.today.year)]
  end

  def data
    distributions = memberships(includes: [:distribution]).map { |m| m.distribution.name }
    stats = Hash.new(0)
    distributions.each { |distribution| stats[distribution] += 1 }
    stats.delete('Domicile')
    stats.sort_by { |_k, v| -1 * v }.to_h
  end
end
