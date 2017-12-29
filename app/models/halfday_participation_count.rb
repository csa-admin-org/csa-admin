class HalfdayParticipationCount
  SCOPES = %i[coming pending validated rejected missing]

  def self.all(year)
    SCOPES.map { |scope| new(year, scope) }
  end

  def initialize(year, scope)
    @participations = HalfdayParticipation.during_year(year)
    @year = year
    @scope = scope
    count # eager load for the cache
  end

  def title
    I18n.t("active_admin.scopes.#{@scope}")
  end

  def count
    @count ||=
      case @scope
      when :missing
        Membership
          .during_year(@year)
          .select('SUM(GREATEST(halfday_works - validated_halfday_works, 0)) as missing')
          .to_a.first[:missing]
      else
        @participations.send(@scope).sum(:participants_count)
      end
  end
end
