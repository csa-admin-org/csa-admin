class Stats::DepotsStat < Stats::BaseStat
  def self.all
    [new(Current.fy_year - 1), new(Current.fy_year)]
  end

  def data
    memberships = memberships(includes: [baskets: :depot])
    depot_ids = memberships.flat_map { |m| m.baskets.map(&:depot_id) }

    all_depots = Depot.all.order(:name).to_a
    all_depots.reject! { |d| d.name.in?(['Domicile', 'La Chaux-du-Milieu']) }
    all_depots.map { |depot|
      [depot.name, depot_ids.count { |id| id == depot.id }]
    }.to_h
  end
end
