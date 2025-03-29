# frozen_string_literal: true

module AdminHelper
  def admin_depots_collection
    grouped_by_visibility(Depot.kept.order_by_name)
  end

  def admin_basket_sizes_collection
    grouped_by_visibility(BasketSize.kept.ordered)
  end

  def admin_basket_complements_collection
    grouped_by_visibility(BasketComplement.kept.ordered)
  end

  def admin_delivery_cycles_collection
    DeliveryCycle.kept.ordered.map { |cycle|
      [
        "#{cycle.name} (#{t('helpers.deliveries_count', count: cycle.deliveries_count)})",
        cycle.id
      ]
    }
  end

  private

  def grouped_by_visibility(relation)
    if relation.hidden.none?
      relation
    else
      grouped_options_for_select({
        t("active_admin.scopes.visible") => relation.visible.map { |a| [ a.name, a.id ] },
        t("active_admin.scopes.hidden") => relation.hidden.map { |a| [ a.name, a.id ] }
      })
    end
  end
end
