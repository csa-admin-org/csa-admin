class ActivityParticipationCount
  include ActiveModel::Model

  SCOPES = %i[coming pending validated rejected paid missing]

  def self.all(year)
    SCOPES.map { |scope| new(year, scope) }
  end

  def initialize(year, scope)
    @participations = ActivityParticipation.during_year(year)
    @year = Current.acp.fiscal_year_for(year)
    @scope = scope
    count # eager load for the cache
  end

  def title
    I18n.t("activerecord.attributes.membership.activity_participations_#{@scope}")
  end

  def url
    routes_helper = Rails.application.routes.url_helpers
    case @scope
    when :missing then nil
    when :paid
      routes_helper.invoices_path(scope: :all, q: {
        object_type_eq: 'ActivityParticipation',
        date_gteq: @year.beginning_of_year,
        date_lteq: @year.end_of_year
      })
    else
      routes_helper.activity_participations_path(scope: @scope, q: {
        activity_date_gteq_datetime: @year.beginning_of_year,
        activity_date_lteq_datetime: @year.end_of_year
      })
    end
  end

  def count
    @count ||=
      case @scope
      when :missing
        Membership.during_year(@year).sum(&:missing_activity_participations)
      when :paid
        Invoice.not_canceled.activity_participation_type.during_year(@year).sum(:paid_missing_activity_participations)
      else
        @participations.send(@scope).sum(:participants_count)
      end
  end
end
