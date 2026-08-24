# frozen_string_literal: true

module Analytics::Series
  extend ActiveSupport::Concern
  include NumbersHelper

  Headline = Data.define(:title, :values)

  class_methods do
    def available? = true
    def icon = "chart-no-axes-combined"
    def page_id = name.demodulize.underscore.to_sym
    def title = I18n.t("analytics.sections.#{page_id}")
  end

  def empty?
    series.none? { |year| year.count.positive? }
  end

  def series
    @series ||= Analytics.fiscal_years.map { |fiscal_year| build_year(fiscal_year) }
  end

  def for(fiscal_year)
    year = Current.org.fiscal_year_for(fiscal_year).year
    series.find { |entry| entry.fiscal_year.year == year }
  end

  def default_year
    series.reverse.find { |year| year.fiscal_year.past? && year.count.positive? } ||
      series.reverse.find { |year| year.fiscal_year.past? } ||
      series.last
  end

  def default_year_index
    @default_year_index ||= series.index(default_year) || 0
  end

  def open_year_index
    series.rindex(&:in_progress?)
  end

  def year_labels
    series.map { |year|
      if year.in_progress?
        "#{year.fiscal_year} (#{I18n.t("analytics.in_progress")})"
      else
        year.fiscal_year.to_s
      end
    }
  end

  private

  def chart
    @chart ||= Analytics::Chart.new(self)
  end

  def headline(title, values)
    Headline.new(title, values)
  end

  def currency_title(title)
    "#{title} (#{Current.org.currency_code})"
  end

  def top_n_title(title, total)
    return title unless total > Analytics::PALETTE_SIZE

    "#{title} (#{I18n.t("analytics.top_n", count: Analytics::PALETTE_SIZE)})"
  end

  def last_n_title(title, total)
    return title unless total > Analytics::PALETTE_SIZE

    "#{title} (#{I18n.t("analytics.last_n", count: Analytics::PALETTE_SIZE)})"
  end

  def format_currency(amount)
    return if amount.nil?

    cur(amount, unit: false)
  end

  def format_percentage(value)
    return unless value

    number_to_percentage(value, precision: 0)
  end

  def format_days(value)
    return unless value

    I18n.t("analytics.metrics.days", count: value.round)
  end

  def decimal_or_nil(value)
    value&.to_f
  end

  def during(fiscal_year)
    rows_by_year[fiscal_year.year] || []
  end

  def group_by_year(rows)
    rows.group_by { |row| Analytics.year_for(row.date) }
  end

  def rate_for(fiscal_year, count, value, closed: false)
    return if closed && !fiscal_year.past?
    return unless count.positive?

    value * 100.0 / count
  end

  def catalog(model, ids)
    model.unscoped.where(id: ids.uniq).ordered.index_by(&:id)
  end
end
