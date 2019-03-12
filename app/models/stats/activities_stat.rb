class Stats::ActivitiesStat < Stats::BaseStat
  def self.all
    [new(Current.fy_year - 1)]
  end

  def data
    {
      'Validées' => ActivityParticipation.during_year(year).validated.sum(:participants_count),
      'Refusées' => ActivityParticipation.during_year(year).rejected.sum(:participants_count),
      'Facturées' => Invoice.not_canceled.activity_participation_type.during_year(year).sum(:paid_missing_activity_participations)
    }.sort_by { |_k, v| -1 * v }
      .select { |_k, v| v.positive? }
      .to_h
  end
end
