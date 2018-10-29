class Stats::DepotsStat < Stats::BaseStat
  def self.all
    [new(Current.fy_year - 1), new(Current.fy_year)]
  end

  def data
    depots =
      memberships(includes: [baskets: :depot])
        .flat_map { |m| m.baskets.map { |b| b.depot.name } }

    all_depots = Depot.order(:name).to_a
    all_depots.select!(&:visible?)
    all_depots.map(&:name).map { |name|
      [name, depots.count { |n| n == name }]
    }.to_h
  end
end
