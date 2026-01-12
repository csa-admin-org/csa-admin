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

  def admin_delivery_cycles
    DeliveryCycle.kept.ordered
  end

  def admin_delivery_cycles_collection
    delivery_cycles_option_for_select(admin_delivery_cycles)
  end

  def admin_delivery_cycles_collection_by_visibility
    cycles = admin_delivery_cycles
    visible_cycles = cycles.visible.to_a
    hidden_cycles = cycles.to_a - visible_cycles

    if hidden_cycles.empty?
      delivery_cycles_option_for_select(cycles)
    else
      [
        [ t("active_admin.scopes.visible"), delivery_cycles_option_for_select(visible_cycles) ],
        [ t("active_admin.scopes.hidden"), delivery_cycles_option_for_select(hidden_cycles) ]
      ]
    end
  end

  def member_cities_collection
    Member.pluck(:city).uniq.map(&:presence).compact.sort
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

  def delivery_cycles_option_for_select(cycles)
    cycles.map { |cycle|
      [
        "#{cycle.name} (#{t('helpers.deliveries_count', count: cycle.deliveries_count)})",
        cycle.id
      ]
    }
  end

  def option_for_select(records, options = nil)
    records.map { |a| [ a.display_name, a.id, options&.call(a) ].compact }
  end
end
