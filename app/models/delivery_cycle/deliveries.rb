# frozen_string_literal: true

module DeliveryCycle::Deliveries
  extend ActiveSupport::Concern

  included do
    after_save :reset_cache!, if: :configuration_or_periods_changed?
  end

  class_methods do
    def for(delivery)
      DeliveryCycle.kept.select { |dc| dc.include_delivery?(delivery) }
    end

    def reset_cache!
      find_each(&:reset_cache!)
    end
  end

  def reset_cache!
    min = Current.org.fiscal_year_for(Delivery.minimum(:date))&.year || Current.fy_year
    max = Current.org.next_fiscal_year.year
    counts = (min..max).map { |y| [ y.to_s, deliveries(y).count ] }.to_h

    update_column(:deliveries_counts, counts)
  end

  def next_delivery
    (current_deliveries + future_deliveries).select { |d| d.date >= Date.current }.min_by(&:date)
  end

  def deliveries_count
    future_deliveries_count.positive? ? future_deliveries_count : current_deliveries_count
  end

  def current_deliveries_count
    deliveries_count_for Current.fy_year
  end

  def future_deliveries_count
    deliveries_count_for Current.fy_year + 1
  end

  def deliveries_count_for(year)
    deliveries_counts[year.to_s].to_i
  end

  def include_delivery?(delivery)
    deliveries(delivery.date).include?(delivery)
  end

  def deliveries_in(range)
    deliveries(range.min).select { |d| range.cover?(d.date) }
  end

  def current_deliveries
    @current_deliveries ||= deliveries(Current.fy_year)
  end

  def future_deliveries
    @future_deliveries ||= deliveries(Current.fy_year + 1)
  end

  def current_and_future_delivery_ids
    (current_deliveries + future_deliveries).map(&:id).uniq
  end

  def coming_deliveries
    (current_deliveries + future_deliveries).select { |d|
      d.date >= Date.current
    }.uniq
  end

  def deliveries(year)
    fiscal_year = Current.org.fiscal_year_for(year)
    first_cweek_year = fiscal_year.beginning_of_year.year
    last_cweek_year = fiscal_year.end_of_year.year

    scoped =
      Delivery
        .where("time_get_weekday(time_parse(date)) IN (?)", wdays)
        .during_year(year)

    if first_cweek.present? && last_cweek.present?
      if exclude_cweek_range?
        # Exclude deliveries inside the range (keep deliveries outside)
        scoped = scoped.where(
          "(time_get_isoyear(time_parse(date)) < :first_year OR time_get_isoweek(time_parse(date)) < :first_cweek) OR " \
          "(time_get_isoyear(time_parse(date)) > :last_year OR time_get_isoweek(time_parse(date)) > :last_cweek)",
          first_year: first_cweek_year,
          first_cweek: first_cweek,
          last_year: last_cweek_year,
          last_cweek: last_cweek
        )
      else
        # Include deliveries inside the range (exclude deliveries outside)
        scoped = scoped.where(
          "time_get_isoyear(time_parse(date)) > :year OR time_get_isoweek(time_parse(date)) >= :cweek",
          year: first_cweek_year,
          cweek: first_cweek
        )
        scoped = scoped.where(
          "time_get_isoyear(time_parse(date)) < :year OR time_get_isoweek(time_parse(date)) <= :cweek",
          year: last_cweek_year,
          cweek: last_cweek
        )
      end
    elsif first_cweek.present?
      scoped = scoped.where(
        "time_get_isoyear(time_parse(date)) > :year OR time_get_isoweek(time_parse(date)) >= :cweek",
        year: first_cweek_year,
        cweek: first_cweek
      )
    elsif last_cweek.present?
      scoped = scoped.where(
        "time_get_isoyear(time_parse(date)) < :year OR time_get_isoweek(time_parse(date)) <= :cweek",
        year: last_cweek_year,
        cweek: last_cweek
      )
    end
    if odd_week_numbers?
      scoped = scoped.where("time_get_isoweek(time_parse(date)) % 2 = ?", 1)
    elsif even_week_numbers?
      scoped = scoped.where("time_get_isoweek(time_parse(date)) % 2 = ?", 0)
    end

    base_deliveries = scoped.to_a

    deliveries = periods.flat_map { |p| p.filter(base_deliveries) }
    deliveries.uniq.sort_by(&:date)
  end
end
