# frozen_string_literal: true

class Analytics
  PAGES = {
    memberships: Memberships,
    billing: Billing,
    absences: Absences,
    activities: Activities,
    basket_content: BasketContents,
    shop: Shop
  }.freeze
  PALETTE = [
    [ 22, 163, 74 ],
    [ 21, 128, 61 ],
    [ 74, 222, 128 ],
    [ 156, 163, 175 ],
    [ 107, 114, 128 ],
    [ 75, 85, 99 ],
    [ 134, 239, 172 ],
    [ 55, 65, 81 ]
  ].freeze
  PALETTE_SIZE = PALETTE.size

  def self.pages
    Current.analytics_cache[:pages] ||= PAGES.keys.select { |page| PAGES[page].available? }
  end

  def self.for(page)
    klass = PAGES[page.to_sym]
    return unless klass

    Current.analytics_cache[:"for_#{page}"] ||= klass.new
  end

  def self.date_range
    years = fiscal_years
    return if years.empty?

    years.first.beginning_of_year..years.last.end_of_year
  end

  def self.past_date_range
    range = date_range
    return unless range

    range.begin..[ range.end, Date.current ].min
  end

  # Skip leading "setup" years that are tiny vs the farm's peak season size.
  SETUP_PEAK_RATIO = 0.15
  SETUP_MIN_COUNT = 20
  SETUP_SMALL_PEAK = 40

  def self.fiscal_years
    Current.analytics_cache[:fiscal_years] ||= begin
      years = org_fiscal_years.reject { |fy| fy.beginning_of_year.future? }
      first = first_meaningful_year
      first ? years.select { |fy| fy.year >= first.year } : years
    end
  end

  def self.first_meaningful_year
    cache = Current.analytics_cache
    return cache[:first_meaningful_year] if cache.key?(:first_meaningful_year)

    cache[:first_meaningful_year] = compute_first_meaningful_year
  end

  def self.year_for(date)
    FiscalYear.year_for(date, start_month: Current.org.fiscal_year_start_month)
  end

  def self.percentile(values, percentile)
    return if values.blank?

    sorted = values.map { |value| value.to_d }.sort
    return sorted.first if sorted.one?

    rank = (percentile.to_d / 100) * (sorted.size - 1)
    lower = rank.floor
    upper = rank.ceil
    return sorted[lower] if lower == upper

    weight = rank - lower
    sorted[lower] + ((sorted[upper] - sorted[lower]) * weight)
  end

  def self.compute_first_meaningful_year
    years = org_fiscal_years
    return if years.empty?

    counts = membership_counts_by_year(years)
    peak = counts.values.max.to_i
    if peak.positive?
      threshold = meaningful_threshold(peak)
      found = years.find { |fy| counts[fy.year].to_i >= threshold }
      return found if found
    end

    amounts = invoice_amounts_by_year(years)
    peak_amount = amounts.values.max.to_d
    return if peak_amount.zero?

    threshold = meaningful_threshold(peak_amount)
    years.find { |fy| amounts[fy.year].to_d >= threshold }
  end
  private_class_method :compute_first_meaningful_year

  def self.org_fiscal_years
    Current.analytics_cache[:org_fiscal_years] ||= compute_org_fiscal_years
  end
  private_class_method :org_fiscal_years

  def self.compute_org_fiscal_years
    min_year = earliest_year
    return [] unless min_year

    max_year = [ year_for(Date.current), Current.fy_year ].max
    (min_year..max_year).map { |year| Current.org.fiscal_year_for(year) }
      .reject { |fy| fy.beginning_of_year.future? }
  end
  private_class_method :compute_org_fiscal_years

  def self.earliest_year
    [
      Delivery.minimum(:date),
      Membership.minimum(:started_on),
      Invoice.not_canceled.minimum(:date)
    ].compact.map { |date| year_for(date) }.min
  end
  private_class_method :earliest_year

  def self.meaningful_threshold(peak)
    peak = peak.to_d
    return (peak * 0.5).ceil if peak < SETUP_SMALL_PEAK

    [ (peak * SETUP_PEAK_RATIO).ceil, SETUP_MIN_COUNT ].max
  end
  private_class_method :meaningful_threshold

  def self.membership_counts_by_year(years)
    counts = Hash.new(0)
    Membership.pluck(:started_on, :ended_on).each do |started_on, ended_on|
      year = year_for(started_on)
      next unless year == year_for(ended_on)

      counts[year] += 1
    end
    years.each_with_object({}) { |fy, hash| hash[fy.year] = counts[fy.year] }
  end
  private_class_method :membership_counts_by_year

  def self.invoice_amounts_by_year(years)
    amounts = Hash.new(0.to_d)
    Invoice.not_canceled.pluck(:date, :amount).each do |date, amount|
      amounts[year_for(date)] += amount.to_d
    end
    years.each_with_object({}) { |fy, hash| hash[fy.year] = amounts[fy.year] }
  end
  private_class_method :invoice_amounts_by_year
end
