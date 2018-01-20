class Stats::HalfdayWorksStat < Stats::BaseStat
  def self.all
    [new(Current.fy_year - 1)]
  end

  def data
    stats = Hash.new(0)
    Member.all.each { |member|
      stats['Effectuées'] += member.validated_halfday_works(year)
      stats['Non-Effectuées (facturées)'] += member.remaining_halfday_works(year)
      stats['Effectuées (extra)'] += member.extra_halfday_works(year)
    }
    stats.sort_by { |_k, v| -1 * v }.to_h
  end
end
