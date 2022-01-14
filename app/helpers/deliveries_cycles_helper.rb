module DeliveriesCyclesHelper
  def week_numbers_collection
    DeliveriesCycle.week_numbers.map { |enum, _|
      [I18n.t("deliveries_cycle.week_numbers.#{enum}"), enum]
    }
  end

  def results_collection
    DeliveriesCycle.results.map { |enum, _|
      [I18n.t("deliveries_cycle.results.#{enum}"), enum]
    }
  end

  def depot_ids_with_only(delivery_cycle)
    Depot.includes(:deliveries_cycles).select { |d|
      d.deliveries_cycle_ids.one? && d.deliveries_cycle_ids.first == delivery_cycle.id
    }.map(&:id)
  end
end
