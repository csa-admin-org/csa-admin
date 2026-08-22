# frozen_string_literal: true

class Analytics::Activities
  include Analytics::Series

  def self.available?
    return false unless Current.org.feature?(:activity)

    range = Analytics.date_range
    return false unless range

    Membership.where("activity_participations_demanded > 0")
      .where(started_on: range, ended_on: range)
      .exists?
  end

  def self.icon = "handshake"
  def self.title = I18n.t("activities.#{Current.org.activity_i18n_scope}.other")

  Year = Data.define(
    :fiscal_year,
    :count,
    :accepted,
    :participated,
    :billed_missing,
    :fulfillment_rate
  ) do
    include Analytics::Year
  end

  def billed_missing?
    Current.org.activity_price.to_d.positive? &&
      series.any? { |year| year.billed_missing.positive? }
  end

  def charts
    [].tap do |panels|
      panels << chart.grouped_bar(
        "demanded-accepted", I18n.t("analytics.charts.demanded_accepted"), self.class.icon,
        [
          [ I18n.t("analytics.metrics.demanded"), series.map(&:count) ],
          [ I18n.t("analytics.metrics.accepted"), series.map(&:accepted) ]
        ])
      panels << chart.line(
        "fulfillment-rate", I18n.t("analytics.charts.fulfillment_rate"), "clipboard-check",
        [ [ I18n.t("analytics.metrics.fulfillment_rate"), series.map { |year| decimal_or_nil(year.fulfillment_rate) } ] ],
        percentage: true, max: :none)
      if billed_missing?
        panels << chart.stacked_area(
          "accepted-mix", I18n.t("analytics.charts.accepted_mix"), "receipt-text",
          [
            [ I18n.t("analytics.metrics.participated"), series.map(&:participated) ],
            [ I18n.t("analytics.metrics.billed_missing"), series.map(&:billed_missing) ]
          ])
      end
    end
  end

  def headlines
    [
      headline(I18n.t("analytics.metrics.demanded"), series.map(&:count)),
      headline(I18n.t("analytics.metrics.accepted"), series.map(&:accepted)),
      headline(I18n.t("analytics.metrics.fulfillment_rate"), series.map { |year| format_percentage(year.fulfillment_rate) }),
      headline(I18n.t("analytics.metrics.billed_missing"), series.map(&:billed_missing))
    ]
  end

  private

  MembershipRow = Data.define(:started_on, :ended_on, :demanded, :accepted)

  def rows
    @rows ||= Membership.pluck(
      :started_on,
      :ended_on,
      :activity_participations_demanded,
      :activity_participations_accepted
    ).map { |values| MembershipRow.new(*values) }
  end

  def billed_missing_by_year
    @billed_missing_by_year ||= begin
      counts = Hash.new(0)
      Invoice.not_canceled.activity_participation_type.pluck(
        :missing_activity_participations_fiscal_year,
        :missing_activity_participations_count
      ).each do |year, count|
        counts[year.to_i] += count.to_i
      end
      counts
    end
  end

  def rows_by_year
    @rows_by_year ||= begin
      grouped = Hash.new { |hash, year| hash[year] = [] }
      rows.each do |row|
        year = Analytics.year_for(row.started_on)
        next unless year == Analytics.year_for(row.ended_on)

        grouped[year] << row
      end
      grouped
    end
  end

  def build_year(fiscal_year)
    memberships = during(fiscal_year)
    demanded = memberships.sum { |row| row.demanded.to_i }
    accepted = memberships.sum { |row| row.accepted.to_i }
    billed_missing = billed_missing_by_year[fiscal_year.year].to_i
    participated = [ accepted - billed_missing, 0 ].max

    Year.new(
      fiscal_year: fiscal_year,
      count: demanded,
      accepted: accepted,
      participated: participated,
      billed_missing: billed_missing,
      fulfillment_rate: rate_for(fiscal_year, demanded, accepted))
  end
end
