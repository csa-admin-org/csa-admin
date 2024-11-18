# frozen_string_literal: true

module AdminHelper
  def admin_depots_collection
    Depot.kept.reorder(:name)
  end

  def admin_basket_sizes_collection
    BasketSize.kept.ordered
  end

  def admin_basket_complements_collection
    BasketComplement.kept.ordered
  end

  def admin_delivery_cycles_collection
    DeliveryCycle.kept.ordered.map { |cycle|
      [
        "#{cycle.name} (#{t('helpers.deliveries_count', count: cycle.deliveries_count)})",
        cycle.id
      ]
    }
  end
end
