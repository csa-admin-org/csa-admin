class HalfdayParticipationCounts
  def self.counts(year)
    instance = new(year)
    cache_key = [
      'halfday_participation_counts',
      HalfdayParticipation.maximum(:updated_at)
    ]
    Rails.cache.fetch cache_key do
      %i{coming pending validated rejected}.each_with_object({}) { |scope, hash|
        hash[scope] = instance.count(scope)
      }.merge(missing: instance.missing_count)
    end
  end

  def initialize(year)
    @participations = HalfdayParticipation.during_year(year)
  end

  def count(scope)
    @participations.send(scope).to_a.sum(&:value)
  end

  def missing_count
    Member.all.to_a.sum(&:remaining_halfday_works)
  end
end
