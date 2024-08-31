# frozen_string_literal: true

module DeliveryCyclesHelper
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
    col = DeliveryCycle.results.map { |enum, _|
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
end
