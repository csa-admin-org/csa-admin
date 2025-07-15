# frozen_string_literal: true

module AdminHelper
  def admin_depots
    Depot.kept.order_by_name
  end

  def admin_depots_collection(options = nil)
    grouped_by_visibility(admin_depots, options)
  end

  def admin_basket_sizes
    BasketSize.kept.ordered
  end

  def admin_basket_sizes_collection(options = nil)
    grouped_by_visibility(admin_basket_sizes, options)
  end

  def admin_basket_complements
    BasketComplement.kept.ordered
  end

  def admin_basket_complements_collection(options = nil)
    grouped_by_visibility(admin_basket_complements, options)
  end

  def admin_delivery_cycles_collection
    DeliveryCycle.kept.ordered.map { |cycle|
      [
        "#{cycle.name} (#{t('helpers.deliveries_count', count: cycle.deliveries_count)})",
        cycle.id
      ]
    }
  end

  def grouped_by_date(relation, past: :last)
    if fy_year = params.dig(:q, :during_year)
      relation = relation.during_year(fy_year)
    end
    if past == :last
      [
        [ t("active_admin.scopes.coming"), option_for_select(relation.coming.order(:date)) ],
        [ t("active_admin.scopes.past"), option_for_select(relation.past.reorder(date: :desc)) ]
      ]
    else
      [
        [ t("active_admin.scopes.past"), option_for_select(relation.past.order(:date)) ],
        [ t("active_admin.scopes.coming"), option_for_select(relation.coming.order(:date)) ]
      ]
    end
  end

  def grouped_by_visibility(relation, options)
    if relation.hidden.none?
      option_for_select(relation, options)
    else
      [
        [ t("active_admin.scopes.visible"), option_for_select(relation.visible) ],
        [ t("active_admin.scopes.hidden"), option_for_select(relation.hidden) ]
      ]
    end
  end

  private

  def option_for_select(relation, options = nil)
    relation.map { |a| [ a.display_name, a.id, options&.call(a) ].compact }
  end
end
