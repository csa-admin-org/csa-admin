# frozen_string_literal: true

class BasketContent
  module Form
    class Distribution
      Entry = Struct.new(
        :id, :name, :percentage, :quantity, :baskets_count,
        keyword_init: true
      )

      def initialize(delivery:, params: {})
        @delivery = delivery
        @params = params
      end

      def to_h
        return empty_result unless delivery

        distribute!

        {
          total_quantity: total_quantity,
          unit: unit,
          total_product_value: compute_total_product_value,
          basket_sizes: basket_sizes_data,
          presets: presets,
          total_changed: total_changed?,
          quantities_changed: quantities_changed
        }
      end

      private

      attr_reader :delivery, :params

      def distribute!
        return if basket_size_entries.empty?

        if preset.present?
          apply_preset
        else
          case distribution_source
          when "total", "percentage"
            distribute_from_total
          when "quantity"
            distribute_from_quantities
          else
            distribute_from_quantities
          end
        end
      end

      def distribute_from_total
        if total_quantity <= 0
          basket_size_entries.each { |entry| entry.quantity = 0 }
          return
        end

        weighted_sum = current_weighted_sum
        return if weighted_sum <= 0

        if kg?
          apply_best_kg_distribution(total_quantity, weighted_sum)
        else
          apply_pc_distribution(total_quantity, weighted_sum)
          compute_total_from_quantities
        end

        recompute_percentages_from_quantities
      end

      def distribute_from_quantities
        compute_total_from_quantities
        recompute_percentages_from_quantities
      end

      def apply_preset
        preset_percentages = case preset
        when "pro_rated" then presets[:pro_rated]
        when "even" then presets[:even]
        else return
        end

        basket_size_entries.each do |entry|
          entry.percentage = preset_percentages[entry.id].to_i
        end

        if total_quantity > 0
          weighted_sum = current_weighted_sum
          if weighted_sum > 0
            if kg?
              apply_best_kg_distribution(total_quantity, weighted_sum)
            else
              apply_pc_distribution(total_quantity, weighted_sum)
              compute_total_from_quantities
            end
          end
        end

        recompute_percentages_from_quantities
      end

      # Given a purchase total, finds the optimal floor/ceil combination for
      # each basket size that maximizes allocated grams without exceeding
      # the total. The search multiplies each candidate value by its basket
      # count (sum(val_i × count_i) ≤ target_grams).

      def apply_best_kg_distribution(total, weighted_sum)
        target_grams = (total * 1000).round

        line_data = basket_size_entries.map do |entry|
          count = entry.baskets_count
          percentage = entry.percentage

          if count == 0 || percentage == 0
            { entry: entry, count: count, ideal_grams: 0, candidates: [ 0 ] }
          else
            ideal_grams = total * (percentage.to_f / weighted_sum) * 1000
            step = ideal_grams < 100 ? 1 : 10
            floor_val = (ideal_grams / step).floor * step
            candidates = [ floor_val ]
            ceil_val = floor_val + step
            # Allow ceil only if within tolerance of ideal
            candidates << ceil_val if ceil_val <= ideal_grams + 20
            { entry: entry, count: count, ideal_grams: ideal_grams, candidates: candidates }
          end
        end

        best = search_best_kg_allocation(line_data, target_grams)

        line_data.each_with_index do |ld, i|
          ld[:entry].quantity = best[:assignment][i]
        end
      end

      # Exhaustive search over floor/ceil combinations per basket size.
      # Finds the combination maximizing sum(val × count) ≤ target_grams.
      def search_best_kg_allocation(line_data, target_grams)
        best_sum = -1
        best_assignment = nil
        current = Array.new(line_data.size)

        recurse = lambda do |idx, allocated_so_far|
          if idx == line_data.size
            if allocated_so_far > best_sum && allocated_so_far <= target_grams
              best_sum = allocated_so_far
              best_assignment = current.dup
            end
            return
          end

          ld = line_data[idx]
          ld[:candidates].each do |val|
            contribution = val * ld[:count]
            if allocated_so_far + contribution <= target_grams
              current[idx] = val
              recurse.call(idx + 1, allocated_so_far + contribution)
            end
          end
        end

        recurse.call(0, 0)

        # Fallback: if no valid assignment found (total too small), use floor values
        if best_assignment.nil?
          best_assignment = line_data.map { |ld| ld[:candidates].first }
          best_sum = line_data.each_with_index.sum { |ld, i| best_assignment[i] * ld[:count] }
        end

        { sum: best_sum, assignment: best_assignment }
      end

      def apply_pc_distribution(total, weighted_sum)
        basket_size_entries.each do |entry|
          count = entry.baskets_count
          percentage = entry.percentage

          if count == 0 || percentage == 0
            entry.quantity = 0
          else
            share = percentage.to_f / weighted_sum
            # Each active basket size gets at least 1 piece
            entry.quantity = [ 1, (total * share).round ].max
          end
        end
      end

      def compute_total_from_quantities
        computed = total_quantity_from_quantities
        @total_quantity = computed
        @total_changed = computed != input_total_quantity
      end

      # Each size's percentage = (quantity / sum_of_quantities) * 100, rounded.
      # Last size adjusted to ensure sum = 100.

      def recompute_percentages_from_quantities
        quantities = basket_size_entries.map { |e| e.quantity }
        total = quantities.sum.to_f
        return if total <= 0

        percentages = quantities.map { |q| ((q / total) * 100).round }

        # Adjust last entry so percentages sum to exactly 100
        diff = 100 - percentages.sum
        percentages[-1] = [ 0, [ 100, percentages[-1] + diff ].min ].max if percentages.any?

        basket_size_entries.each_with_index do |entry, i|
          entry.percentage = percentages[i]
        end
      end

      def basket_size_entries
        @basket_size_entries ||= build_basket_size_entries
      end

      def build_basket_size_entries
        basket_sizes_ordered.map do |bs|
          Entry.new(
            id: bs.id,
            name: bs.name,
            percentage: input_percentage_for(bs.id),
            quantity: input_quantity_for(bs.id),
            baskets_count: baskets_count_for(bs.id))
        end
      end

      def basket_sizes_ordered
        @basket_sizes_ordered ||= BasketSize.paid.ordered
      end

      def input_total_quantity
        @input_total_quantity ||= begin
          value = params[:total_quantity].to_s.presence&.to_f || 0
          kg? ? round_kg_input_total(value) : ceil_pc_total(value)
        end
      end

      def total_quantity
        @total_quantity ||= input_total_quantity
      end

      def unit
        @unit ||= params[:unit].presence || product&.unit || "kg"
      end

      def kg?
        unit == "kg"
      end

      def unit_price
        @unit_price ||= params[:unit_price].to_f
      end

      def distribution_source
        params[:distribution_source].presence
      end

      def preset
        params[:preset].presence
      end

      def depot_ids
        @depot_ids ||= begin
          if params.key?(:depot_ids) || params.key?("depot_ids")
            Array(params[:depot_ids] || params["depot_ids"]).map(&:to_i).reject(&:zero?)
          elsif params[:depot_ids_empty] == "1" || params["depot_ids_empty"] == "1"
            []
          else
            Depot.kept.pluck(:id)
          end
        end
      end

      def basket_content_id
        params[:id].presence&.to_i
      end

      def product_id
        params[:product_id].presence
      end

      def product
        @product ||= BasketContent::Product.find_by(id: product_id)
      end

      def input_percentages
        @input_percentages ||= begin
          pcts = params[:basket_size_ids_percentages]
          return {} unless pcts

          hash = pcts.respond_to?(:to_unsafe_h) ? pcts.to_unsafe_h : pcts.to_h
          hash.transform_keys(&:to_i).transform_values(&:to_i)
        end
      end

      def input_quantities
        @input_quantities ||= begin
          qtys = params[:basket_size_ids_quantities]
          return {} unless qtys

          hash = qtys.respond_to?(:to_unsafe_h) ? qtys.to_unsafe_h : qtys.to_h
          hash.transform_keys(&:to_i).transform_values(&:to_i)
        end
      end

      def input_percentage_for(basket_size_id)
        input_percentages[basket_size_id] || 0
      end

      def input_quantity_for(basket_size_id)
        input_quantities[basket_size_id] || 0
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

      def baskets_count_for(basket_size_id)
        baskets_counts[basket_size_id] || 0
      end

      def basket_size_ids
        @basket_size_ids ||= BasketSize.paid.pluck(:id)
      end

      def current_weighted_sum
        basket_size_entries.sum { |e| e.baskets_count * e.percentage }
      end

      def total_quantity_from_quantities
        if kg?
          total_grams = basket_size_entries.sum { |e| e.quantity * e.baskets_count }
          ceil_kg_total(total_grams)
        else
          total_pieces = basket_size_entries.sum { |e| e.quantity * e.baskets_count }
          ceil_pc_total(total_pieces)
        end
      end

      def round_kg_input_total(quantity)
        return 0 unless quantity > 0

        (quantity * 10).round / 10.0
      end

      def ceil_kg_total(total_grams)
        return 0 unless total_grams > 0

        (total_grams / 100.0).ceil / 10.0
      end

      def ceil_pc_total(count)
        return 0 unless count > 0

        count.ceil
      end

      def total_changed?
        @total_changed || false
      end

      def quantities_changed
        @quantities_changed ||= basket_size_entries.filter_map do |entry|
          original = input_quantity_for(entry.id)
          entry.id if entry.quantity != original
        end
      end

      def compute_total_product_value
        basket_size_entries.sum do |entry|
          basket_quantity_in_unit(entry.quantity) * unit_price * entry.baskets_count
        end.round(2)
      end

      def basket_sizes_data
        basket_size_entries.map do |entry|
          bs = basket_sizes_ordered.find { |b| b.id == entry.id }
          basket_qty = basket_quantity_in_unit(entry.quantity)
          product_price = (basket_qty * unit_price).round(2)
          baskets_count = entry.baskets_count

          {
            id: entry.id,
            name: entry.name,
            percentage: entry.percentage,
            quantity: entry.quantity,
            baskets_count: baskets_count,
            product_price: product_price,
            total_value: (product_price * baskets_count).round(2),
            basket_price: delivery_basket_price(bs),
            totals: depot_totals_for(bs)
          }
        end
      end

      # Convert form quantity (grams or pieces) to the unit used by BasketContent
      # (kg float or pieces integer) for price computation.
      def basket_quantity_in_unit(quantity)
        kg? ? quantity / 1000.0 : quantity.to_f
      end

      def delivery_basket_price(basket_size)
        delivery.basket_size_price_for(basket_size.price_for(delivery.fy_year))
      end

      def depot_totals_for(basket_size)
        totals = delivery.depots.filter_map do |depot|
          existing_total = existing_contents.sum { |c| c.price_for(basket_size, depot) || 0 }
          entry = basket_size_entries.find { |e| e.id == basket_size.id }
          current_price = if entry && depot_ids.include?(depot.id)
            basket_quantity_in_unit(entry.quantity) * unit_price
          else
            0
          end
          total = (existing_total + current_price).round(2)
          total if total > 0
        end

        totals.any? ? [ totals.min, totals.max ].uniq : []
      end

      def existing_contents
        @existing_contents ||= begin
          contents = delivery.basket_contents.with_unit_price.includes(:depots).to_a
          basket_content_id ? contents.reject { |c| c.id == basket_content_id } : contents
        end
      end

      def presets
        @presets ||= {
          pro_rated: BasketContent.basket_size_ids_percentages_pro_rated,
          even: BasketContent.basket_size_ids_percentages_even
        }
      end

      def empty_result
        {
          total_quantity: 0,
          unit: unit,
          total_product_value: 0,
          basket_sizes: [],
          presets: { pro_rated: {}, even: {} },
          total_changed: false,
          quantities_changed: []
        }
      end
    end
  end
end
