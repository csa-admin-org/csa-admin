# frozen_string_literal: true

class BasketContent
  class FormPricePreview
    def initialize(delivery:, params: {})
      @delivery = delivery
      @params = params
    end

    def to_h
      return empty_result unless delivery

      result = empty_result(baskets_counts)
      return result unless unit.present?

      result.merge!(
        total_quantity_surplus: basket_content.quantity_surplus,
        total_quantity_surplus_unit: basket_content.quantity_surplus_unit,
        unit: basket_content.unit)
      return result unless price_preview?

      result.merge(
        prices_data: prices_data,
        total_product_value: total_product_value)
    end

    private

    attr_reader :delivery, :params

    def empty_result(baskets_counts = {})
      {
        prices_data: {},
        baskets_counts: baskets_counts,
        unit: unit,
        total_product_value: 0,
        total_quantity_surplus: 0,
        total_quantity_surplus_unit: unit == "kg" ? "g" : unit
      }
    end

    def price_preview?
      unit.present? && unit_price.positive?
    end

    def prices_data
      @prices_data ||= BasketSize.paid.reorder(:price).filter_map do |basket_size|
        basket_size_price_data(basket_size)
      end.to_h
    end

    def basket_size_price_data(basket_size)
      depot_totals = depot_totals_for(basket_size)
      return if depot_totals.empty?

      basket_quantity = basket_content.basket_quantity(basket_size).to_f
      product_price = (basket_quantity * basket_content.unit_price).round_to_one_cent
      basket_price = delivery.basket_size_price_for(basket_size.price_for(delivery.fy_year))
      baskets_count = baskets_counts[basket_size.id].to_i

      [ basket_size.id, {
        basket_quantity: basket_quantity,
        unit: basket_content.unit,
        baskets_count: baskets_count,
        product_price: product_price,
        total_value: (product_price * baskets_count).round_to_one_cent,
        totals: [ depot_totals.values.min, depot_totals.values.max ].uniq,
        basket_price: basket_price,
        depot_totals: depot_totals.size > 1 ? depot_totals : nil
      } ]
    end

    def depot_totals_for(basket_size)
      delivery.depots.filter_map do |depot|
        existing_total = existing_contents.sum { |content| content.price_for(basket_size, depot) || 0 }
        current_total = basket_content.price_for(basket_size, depot) || 0
        total = (existing_total + current_total).round_to_one_cent
        [ depot, total ] if total.positive?
      end.to_h
    end

    def total_product_value
      prices_data.values.sum { |info| info[:total_value] }.round_to_one_cent
    end

    def basket_content
      @basket_content ||= BasketContent.new(
        delivery: delivery,
        product_id: product_id,
        unit: unit,
        unit_price: unit_price).tap do |basket_content|
          basket_content.depot_ids = depot_ids
          basket_content.baskets_counts_hash = baskets_counts
          basket_content.basket_size_ids_quantities = basket_size_quantities
        end
    end

    def baskets_counts
      @baskets_counts ||= begin
        counts = delivery.baskets.active
          .where(depot_id: depot_ids, basket_size_id: basket_size_ids)
          .group(:basket_size_id)
          .sum(:quantity)

        basket_size_ids.index_with { |id| counts[id] || 0 }
      end
    end

    def existing_contents
      @existing_contents ||= begin
        contents = delivery.basket_contents.with_unit_price.includes(:depots).to_a
        basket_content_id ? contents.reject { |content| content.id == basket_content_id } : contents
      end
    end

    def basket_size_ids
      @basket_size_ids ||= BasketSize.paid.pluck(:id)
    end

    def depot_ids
      @depot_ids ||= begin
        ids = Array(params[:depot_ids]).map(&:to_i).reject(&:zero?)
        ids.presence || (params[:depot_ids_empty] ? [] : Depot.kept.pluck(:id))
      end
    end

    def basket_size_quantities
      quantities = params[:basket_size_ids_quantities]
      return {} unless quantities

      quantities.respond_to?(:to_unsafe_h) ? quantities.to_unsafe_h : quantities.to_h
    end

    def basket_content_id
      params[:id].presence&.to_i
    end

    def product_id
      params[:product_id].presence
    end

    def unit
      params[:unit]
    end

    def unit_price
      params[:unit_price].to_f
    end
  end
end
