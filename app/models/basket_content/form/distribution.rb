# frozen_string_literal: true

class BasketContent
  module Form
    class Distribution
      Entry = Struct.new(
        :id, :name, :percentage, :target_percentage, :quantity, :baskets_count,
        keyword_init: true
      )
      PC_EACH_PRESETS = {
        "pc_1_each" => 1,
        "pc_2_each" => 2
      }.freeze

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
          reset_percentages(update_target: kg?)
          return
        end

        weighted_sum = current_weighted_sum
        if weighted_sum <= 0
          apply_percentages(presets[:pro_rated])
          weighted_sum = current_weighted_sum
        end
        return if weighted_sum <= 0

        if kg?
          apply_best_kg_distribution(total_quantity, weighted_sum)
          recompute_percentages_from_quantities
        else
          apply_best_pc_distribution(
            total_quantity,
            weighted_sum,
            prioritize_total: distribution_source == "total")
          compute_total_from_quantities
          recompute_percentages_from_quantities(update_target: false)
        end
      end

      def distribute_from_quantities
        compute_total_from_quantities
        recompute_percentages_from_quantities
      end

      def apply_preset
        if pc_each_quantity = pc_each_preset_quantity
          apply_pc_each_preset(pc_each_quantity)
        else
          apply_percentage_preset
        end
      end

      def apply_percentage_preset
        preset_percentages = case preset
        when "pro_rated" then presets[:pro_rated]
        when "even" then presets[:even]
        else return
        end

        apply_percentages(preset_percentages)

        if total_quantity > 0
          weighted_sum = current_weighted_sum
          if weighted_sum > 0
            if kg?
              apply_best_kg_distribution(total_quantity, weighted_sum)
              recompute_percentages_from_quantities
            else
              apply_best_pc_distribution(total_quantity, weighted_sum, prioritize_total: false)
              compute_total_from_quantities
              recompute_percentages_from_quantities(update_target: false)
            end
          end
        elsif kg?
          recompute_percentages_from_quantities
        else
          basket_size_entries.each { |entry| entry.quantity = 0 }
          reset_percentages(update_target: false)
        end
      end

      def pc_each_preset_quantity
        PC_EACH_PRESETS[preset] if pc?
      end

      def apply_pc_each_preset(quantity)
        basket_size_entries.each do |entry|
          entry.quantity = entry.baskets_count.positive? ? quantity : 0
        end
        compute_total_from_quantities
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
          target_percentage = entry.target_percentage

          if count == 0 || target_percentage == 0
            { entry: entry, count: count, ideal_grams: 0, candidates: [ 0 ] }
          else
            ideal_grams = total * (target_percentage.to_f / weighted_sum) * 1000
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

      def apply_best_pc_distribution(total, weighted_sum, prioritize_total: true)
        target_pieces = ceil_pc_total(total)
        line_data = basket_size_entries.map do |entry|
          pc_line_data(entry, target_pieces, weighted_sum)
        end
        best = search_best_pc_allocation(line_data, target_pieces, prioritize_total: prioritize_total)

        line_data.each_with_index do |line, i|
          line[:entry].quantity = best[:assignment][i]
        end
      end

      def pc_line_data(entry, target_pieces, weighted_sum)
        count = entry.baskets_count
        target_percentage = entry.target_percentage
        active = count.positive? && target_percentage.positive?
        max_quantity = active ? target_pieces / count : 0
        ideal_quantity = active ? target_pieces * (target_percentage.to_f / weighted_sum) : 0
        basket_size = basket_sizes_by_id[entry.id]

        {
          entry: entry,
          count: count,
          target_percentage: target_percentage,
          max_quantity: max_quantity,
          ideal_quantity: ideal_quantity,
          basket_price: basket_size ? delivery_basket_price(basket_size).to_f : 0,
          existing_prices: basket_size ? existing_depot_prices_for(basket_size) : [],
          candidates: (0..max_quantity).to_a
        }
      end

      def search_best_pc_allocation(line_data, target_pieces, prioritize_total:)
        states = { 0 => { assignment: [], score: empty_pc_score } }

        line_data.each do |line|
          states = next_pc_allocation_states(states, line, target_pieces)
        end

        if prioritize_total
          states[states.keys.max]
        else
          states.min_by { |allocated, state| pc_distribution_state_score(state, allocated, target_pieces) }.last
        end
      end

      def empty_pc_score
        {
          distribution_error: 0.0,
          price_diff_sum: 0.0,
          price_diff_square_sum: 0.0,
          price_diff_count: 0,
          zeroed_count: 0,
          zeroed_percentage: 0
        }
      end

      def next_pc_allocation_states(states, line, target_pieces)
        states.each_with_object({}) do |(allocated, state), next_states|
          line[:candidates].each do |quantity|
            next_allocated = allocated + quantity * line[:count]
            next if next_allocated > target_pieces

            next_state = {
              assignment: state[:assignment] + [ quantity ],
              score: add_pc_scores(state[:score], pc_quantity_score(line, quantity))
            }
            current_state = next_states[next_allocated]
            next_states[next_allocated] = next_state if current_state.nil? || better_pc_state?(next_state, current_state)
          end
        end
      end

      def pc_quantity_score(line, quantity)
        score = empty_pc_score
        score[:distribution_error] = ((quantity - line[:ideal_quantity])**2) * line[:count]
        score.merge!(pc_price_diff_stats(line, quantity))

        if line[:max_quantity].positive? && line[:target_percentage].positive? && quantity.zero?
          score[:zeroed_count] = 1
          score[:zeroed_percentage] = line[:target_percentage]
        end

        score
      end

      def pc_price_diff_stats(line, quantity)
        return {} if unit_price <= 0 || line[:basket_price] <= 0 || line[:existing_prices].empty?

        current_price = quantity * unit_price
        relative_diffs = line[:existing_prices].map do |existing_price|
          (existing_price + current_price - line[:basket_price]) / line[:basket_price]
        end

        {
          price_diff_sum: relative_diffs.sum,
          price_diff_square_sum: relative_diffs.sum { |diff| diff**2 },
          price_diff_count: relative_diffs.size
        }
      end

      def add_pc_scores(first, second)
        first.merge(second) { |_key, a, b| a + b }
      end

      def pc_distribution_state_score(state, allocated, target_pieces)
        unused_pieces = target_pieces - allocated
        score = state[:score]
        [
          score[:distribution_error] + unused_pieces,
          pc_price_equilibrium_score(score),
          score[:zeroed_count],
          score[:zeroed_percentage],
          unused_pieces
        ]
      end

      def pc_state_score(score)
        [
          score[:distribution_error],
          pc_price_equilibrium_score(score),
          score[:zeroed_count],
          score[:zeroed_percentage]
        ]
      end

      def pc_price_equilibrium_score(score)
        return [ 0, 0 ] if score[:price_diff_count] <= 1

        mean = score[:price_diff_sum] / score[:price_diff_count]
        mean_square = score[:price_diff_square_sum] / score[:price_diff_count]
        variance = mean_square - mean**2
        [ [ variance, 0 ].max, mean_square ]
      end

      def better_pc_state?(candidate, current)
        (pc_state_score(candidate[:score]) <=> pc_state_score(current[:score])).negative?
      end

      def compute_total_from_quantities
        computed = total_quantity_from_quantities
        @total_quantity = computed
        @total_changed = computed != input_total_quantity
      end

      # Each size's percentage = (quantity / sum_of_quantities) * 100, rounded.
      # Last size adjusted to ensure sum = 100.

      def recompute_percentages_from_quantities(update_target: true)
        quantities = basket_size_entries.map { |e| e.quantity }
        total = quantities.sum.to_f
        return reset_percentages(update_target: update_target) if total <= 0

        percentages = quantities.map { |q| ((q / total) * 100).round }

        # Adjust last entry so percentages sum to exactly 100
        diff = 100 - percentages.sum
        percentages[-1] = [ 0, [ 100, percentages[-1] + diff ].min ].max if percentages.any?

        basket_size_entries.each_with_index do |entry, i|
          entry.percentage = percentages[i]
          entry.target_percentage = percentages[i] if update_target
        end
      end

      def reset_percentages(update_target: true)
        basket_size_entries.each do |entry|
          entry.percentage = 0
          entry.target_percentage = 0 if update_target
        end
      end

      def apply_percentages(percentages)
        basket_size_entries.each do |entry|
          percentage = percentages[entry.id].to_i
          entry.percentage = percentage
          entry.target_percentage = percentage
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
            target_percentage: input_target_percentage_for(bs.id),
            quantity: input_quantity_for(bs.id),
            baskets_count: baskets_count_for(bs.id))
        end
      end

      def basket_sizes_ordered
        @basket_sizes_ordered ||= BasketSize.paid.ordered
      end

      def basket_sizes_by_id
        @basket_sizes_by_id ||= basket_sizes_ordered.index_by(&:id)
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

      def pc?
        unit == "pc"
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

      def input_target_percentages
        @input_target_percentages ||= begin
          pcts = params[:basket_size_ids_target_percentages]
          return {} unless pcts

          hash = pcts.respond_to?(:to_unsafe_h) ? pcts.to_unsafe_h : pcts.to_h
          hash.transform_keys(&:to_i).transform_values(&:to_i)
        end
      end

      def input_percentage_for(basket_size_id)
        input_percentages[basket_size_id] || 0
      end

      def input_target_percentage_for(basket_size_id)
        input_target_percentages.fetch(basket_size_id) { input_percentage_for(basket_size_id) }
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
        basket_size_entries.sum { |e| e.baskets_count * e.target_percentage }
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
            target_percentage: entry.target_percentage,
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

      def existing_depot_prices_for(basket_size)
        selected_depots.map do |depot|
          existing_contents.sum { |content| content.price_for(basket_size, depot) || 0 }.to_f
        end
      end

      def selected_depots
        @selected_depots ||= delivery.depots.select { |depot| depot_ids.include?(depot.id) }
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
