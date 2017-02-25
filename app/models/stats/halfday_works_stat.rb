class Stats::HalfdayWorksStat < Stats::BaseStat
  def self.all
    [new(Date.today.year - 1)]
  end

  def data
    stats = Hash.new(0)
    Member.all.each { |member|
      stats['Effectuées'] += member.validated_halfday_works(year)
      stats['Non-Effectuées'] += member.remaining_halfday_works(year)
      stats['Non-Effectuées (Payées)'] += member.skipped_halfday_works(year)
      stats['Effectuées (extra)'] += member.extra_halfday_works(year)
    }
    stats.sort_by { |_k, v| -1 * v }.to_h
  end
end
