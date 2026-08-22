# frozen_string_literal: true

class Analytics::Absences
  include Analytics::Series

  def self.available?
    return false unless Current.org.feature?(:absence)

    range = Analytics.date_range
    return false unless range

    Absence.where("started_on <= ? AND ended_on >= ?", range.end, range.begin).exists?
  end

  def self.icon = "tent"

  Year = Data.define(
    :fiscal_year,
    :count,
    :member_count,
    :absent_baskets,
    :countable_baskets,
    :absent_rate,
    :declared_quota,
    :leftover_quota,
    :announcement_delay
  ) do
    include Analytics::Year
  end

  def announcement_delay?
    series.any? { |year| year.announcement_delay }
  end

  def included_quota?
    series.any? { |year| year.declared_quota.positive? || year.leftover_quota.positive? }
  end

  def charts
    [].tap do |panels|
      panels << chart.grouped_bar(
        "absences", I18n.t("analytics.charts.absences"), self.class.icon,
        [
          [ I18n.t("analytics.metrics.absences"), series.map(&:count) ],
          [ I18n.t("analytics.metrics.absent_members"), series.map(&:member_count) ]
        ])
      panels << chart.rate_line(
        "absent-basket-rate", I18n.t("analytics.charts.absent_basket_rate"), "shopping-bag",
        [ [ I18n.t("analytics.metrics.absent_basket_rate"), series.map { |year| decimal_or_nil(year.absent_rate) } ] ])
      if included_quota?
        panels << chart.stacked_area(
          "included-quota", I18n.t("analytics.charts.included_quota"), self.class.icon,
          [
            [ I18n.t("analytics.metrics.declared_included"), series.map(&:declared_quota) ],
            [ I18n.t("analytics.metrics.unused_included"), series.map(&:leftover_quota) ]
          ])
      end
      if announcement_delay?
        panels << chart.line(
          "announcement-delay", I18n.t("analytics.charts.announcement_delay"), "clock",
          [ [ I18n.t("analytics.metrics.announcement_delay"), series.map { |year| decimal_or_nil(year.announcement_delay) } ] ])
      end
    end
  end

  def headlines
    [
      headline(I18n.t("analytics.metrics.absences"), series.map(&:count)),
      headline(I18n.t("analytics.metrics.absent_members"), series.map(&:member_count)),
      headline(I18n.t("analytics.metrics.absent_baskets"), series.map(&:absent_baskets)),
      headline(I18n.t("analytics.metrics.absent_basket_rate"), series.map { |year| format_percentage(year.absent_rate) })
    ]
  end

  private

  AbsenceRow = Data.define(:member_id, :started_on, :ended_on, :created_at)
  MembershipRow = Data.define(:id, :started_on, :ended_on, :absences_included, :salary_basket)
  BasketRow = Data.define(:date, :state, :salary_basket, :absence_id, :billable, :membership_id)

  def rows
    @rows ||= Absence.pluck(:member_id, :started_on, :ended_on, :created_at)
      .map { |values| AbsenceRow.new(*values) }
  end

  def membership_rows
    @membership_rows ||= Membership.joins("INNER JOIN members ON members.id = memberships.member_id").pluck(
      :id,
      :started_on,
      :ended_on,
      :absences_included,
      "members.salary_basket"
    ).map { |values| MembershipRow.new(*values) }
  end

  def basket_rows
    @basket_rows ||= Basket.unscoped.joins(:delivery, :membership)
      .joins("INNER JOIN members ON members.id = memberships.member_id")
      .pluck(
        "deliveries.date",
        "baskets.state",
        "members.salary_basket",
        "baskets.absence_id",
        "baskets.billable",
        "baskets.membership_id"
      ).map { |values| BasketRow.new(*values) }
  end

  def rows_by_year
    @rows_by_year ||= begin
      grouped = Hash.new { |hash, year| hash[year] = [] }
      rows.each do |row|
        overlapping_years(row).each { |year| grouped[year] << row }
      end
      grouped
    end
  end

  def memberships_by_year
    @memberships_by_year ||= begin
      grouped = Hash.new { |hash, year| hash[year] = [] }
      membership_rows.each do |row|
        next if row.salary_basket

        year = Analytics.year_for(row.started_on)
        next unless year == Analytics.year_for(row.ended_on)

        grouped[year] << row
      end
      grouped
    end
  end

  def baskets_by_year
    @baskets_by_year ||= group_by_year(basket_rows)
  end

  def overlapping_years(row)
    Analytics.year_for(row.started_on)..Analytics.year_for(row.ended_on)
  end

  def build_year(fiscal_year)
    absences = during(fiscal_year)
    baskets = countable_baskets(fiscal_year)
    absent_baskets = baskets.count { |row| row.state == "absent" }
    countable = baskets.size
    declared, leftover = quota_for(fiscal_year, baskets)

    Year.new(
      fiscal_year: fiscal_year,
      count: absences.size,
      member_count: absences.map(&:member_id).uniq.size,
      absent_baskets: absent_baskets,
      countable_baskets: countable,
      absent_rate: rate_for(fiscal_year, countable, absent_baskets),
      declared_quota: declared,
      leftover_quota: leftover,
      announcement_delay: delay_for(fiscal_year, absences))
  end

  def quota_for(fiscal_year, baskets)
    declared_by_membership = baskets
      .select { |row| declared_quota?(row) }
      .group_by(&:membership_id)
      .transform_values(&:size)

    declared = leftover = 0
    (memberships_by_year[fiscal_year.year] || []).each do |membership|
      included = membership.absences_included.to_i
      next unless included.positive?

      used = [ declared_by_membership[membership.id].to_i, included ].min
      declared += used
      leftover += included - used
    end
    [ declared, leftover ]
  end

  def declared_quota?(row)
    row.state == "absent" && row.absence_id.present? && !row.billable
  end

  def countable_baskets(fiscal_year)
    (baskets_by_year[fiscal_year.year] || []).reject { |row|
      row.salary_basket || row.date.future?
    }
  end

  def delay_for(_fiscal_year, absences)
    return unless absences.any?

    days = absences.map { |row|
      [ (row.started_on - row.created_at.to_date).to_i, 0 ].max
    }
    Analytics.percentile(days, 50)
  end
end
