class Stats::DistributionsStat < Stats::BaseStat
  def self.all
    [new(Current.fy_year - 1), new(Current.fy_year)]
  end

  def data
    distributions =
      memberships(includes: [baskets: :distribution])
        .flat_map { |m| m.baskets.map { |b| b.distribution.name } }

    all_distributions = Distribution.order(:name).to_a
    all_distributions.select!(&:visible?)
    all_distributions.map(&:name).map { |name|
      [name, distributions.count { |n| n == name }]
    }.to_h
  end
end
