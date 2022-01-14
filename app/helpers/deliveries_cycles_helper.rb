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
end
