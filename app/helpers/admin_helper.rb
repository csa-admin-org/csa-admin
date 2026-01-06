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
    cycles = DeliveryCycle.kept.ordered
    if DeliveryCycle.visible?
      [
        [ t("active_admin.scopes.visible"), cycles_option_for_select(cycles.visible) ],
        [ t("active_admin.scopes.hidden"), cycles_option_for_select(cycles.where.not(id: cycles.visible)) ]
      ]
    else
      cycles_option_for_select(cycles)
    end
  end

  def cycles_option_for_select(cycles)
    cycles.map { |cycle|
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
    # Load all records once and partition in Ruby to avoid N+1 queries
    all_records = relation.to_a
    visible_records, hidden_records = all_records.partition(&:visible?)

    if hidden_records.empty?
      option_for_select(all_records, options)
    else
      [
        [ t("active_admin.scopes.visible"), option_for_select(visible_records) ],
        [ t("active_admin.scopes.hidden"), option_for_select(hidden_records) ]
      ]
    end
  end

  private

  def option_for_select(records, options = nil)
    records.map { |a| [ a.display_name, a.id, options&.call(a) ].compact }
  end
end
