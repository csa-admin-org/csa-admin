# frozen_string_literal: true

module DeliveryCyclesHelper
  def delivery_cycle_link(delivery_cycle, fy_year: nil)
    return unless delivery_cycle

    count ||=
      if fy_year
        delivery_cycle.deliveries_count_for(fy_year)
      else
        delivery_cycle.deliveries_count
      end
    content_tag(:span, class: "flex items-center gap-2") {
      auto_link(delivery_cycle) +
        content_tag(:span, count, class: "panel-title-count text-sm").html_safe
    }
  end

  def deliveries_current_year_title
    fiscal_year = Current.org.current_fiscal_year
    "#{Delivery.model_name.human(count: 2)} (#{fiscal_year})"
  end

  def deliveries_next_year_title
    fiscal_year = Current.org.fiscal_year_for(1.year.from_now)
    "#{Delivery.model_name.human(count: 2)} (#{fiscal_year})"
  end

  def week_numbers_collection
    DeliveryCycle.week_numbers.map { |enum, _|
      [ I18n.t("delivery_cycle.week_numbers.#{enum}"), enum ]
    }
  end

  def results_collection
    col = DeliveryCycle::Period.results.map { |enum, _|
      [ I18n.t("delivery_cycle.results.#{enum}"), enum ]
    }
    # Move "all_but_first" just after "all"
    col.insert(1, col.delete_at(7))
    col
  end

  def depot_ids_with_only(delivery_cycle)
    Depot.kept.includes(:delivery_cycles).select { |d|
      d.delivery_cycle_ids.one? && d.delivery_cycle_ids.first == delivery_cycle.id
    }.map(&:id)
  end

  # Returns a collection of fiscal-year months (1-12) with their names
  # ordered by the fiscal year start month. Months falling in the next
  # calendar year are marked with *.
  def fy_months_collection
    fy_start_month = Current.fiscal_year.range.min.month
    (1..12).map { |fy_month|
      calendar_month = ((fy_start_month - 1 + fy_month - 1) % 12) + 1
      name = I18n.t("date.month_names")[calendar_month].capitalize
      # Mark months that fall in the next calendar year
      if fy_start_month > 1 && calendar_month < fy_start_month
        name = "#{name} *"
      end
      [ name, fy_month ]
    }
  end

  # Returns the calendar month name for a given fiscal-year month (1-12).
  # FY month 1 corresponds to the first month of the fiscal year.
  def fy_month_name(fy_month)
    fy_start_month = Current.fiscal_year.range.min.month
    calendar_month = ((fy_start_month - 1 + fy_month - 1) % 12) + 1
    I18n.t("date.month_names")[calendar_month].capitalize
  end

  # Returns a hint explaining the "*" marker for months in the next calendar year.
  # Returns nil if the fiscal year starts in January (no marker needed).
  def fy_months_next_year_hint
    return nil if Current.fiscal_year.range.min.month == 1

    I18n.t("formtastic.hints.delivery_cycle/period.fy_months_next_year")
  end
end
