class HalfdayParticipationCounts
  SCOPES = %i[coming pending validated rejected missing]

  def self.counts(year)
    cache_key = [name, HalfdayParticipation.maximum(:updated_at)]
    Rails.cache.fetch cache_key do
      SCOPES.map { |scope| new(year, scope) }
    end
  end

  attr_reader :count

  def initialize(year, scope)
    @participations = HalfdayParticipation.during_year(year)
    @scope = scope
    count # eager load for the cache
  end

  def title
    I18n.t("active_admin.scopes.#{@scope}")
  end

  def count
    @count ||=
      case @scope
      when :missing then Member.all.to_a.sum(&:remaining_halfday_works)
      else
        @participations.send(@scope).to_a.sum(&:value)
      end
  end
end
