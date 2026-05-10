# frozen_string_literal: true

class SimplifyBasketContentsSchema < ActiveRecord::Migration[8.0]
  def up
    # 1. Drop old check constraints first (before data transformation)
    remove_check_constraint :basket_contents, name: "basket_contents_basket_percentages_is_array"
    remove_check_constraint :basket_contents, name: "basket_contents_basket_quantities_is_array"
    remove_check_constraint :basket_contents, name: "basket_contents_basket_size_ids_is_array"
    remove_check_constraint :basket_contents, name: "basket_contents_baskets_counts_is_array"

    # 2. Transform basket_quantities from JSON array to JSON object
    #    using basket_size_ids as keys
    execute <<~SQL
      UPDATE basket_contents
      SET basket_quantities = COALESCE(
        (
          SELECT json_group_object(CAST(key.value AS TEXT), qty.value)
          FROM json_each(basket_size_ids) AS key
          JOIN json_each(basket_quantities) AS qty ON key.key = qty.key
        ),
        '{}'
      )
    SQL

    # 3. Drop columns that are now computed or removed
    remove_column :basket_contents, :distribution_mode
    remove_column :basket_contents, :quantity
    remove_column :basket_contents, :surplus_quantity
    remove_column :basket_contents, :basket_percentages
    remove_column :basket_contents, :basket_size_ids
    remove_column :basket_contents, :baskets_counts

    # 4. Change basket_quantities default and add object constraint
    change_column_default :basket_contents, :basket_quantities, from: [], to: {}
    add_check_constraint :basket_contents,
      "JSON_TYPE(basket_quantities) = 'object'",
      name: "basket_contents_basket_quantities_is_object"
  end

  def down
    remove_check_constraint :basket_contents, name: "basket_contents_basket_quantities_is_object"

    change_column_default :basket_contents, :basket_quantities, from: {}, to: []

    add_column :basket_contents, :distribution_mode, :string, default: "automatic", null: false
    add_column :basket_contents, :quantity, :decimal, precision: 8, scale: 2, null: false, default: 0
    add_column :basket_contents, :surplus_quantity, :decimal, precision: 8, scale: 2, null: false, default: 0
    add_column :basket_contents, :basket_percentages, :json, default: [], null: false
    add_column :basket_contents, :basket_size_ids, :json, default: [], null: false
    add_column :basket_contents, :baskets_counts, :json, default: [], null: false

    restore_legacy_basket_content_columns
    change_column_default :basket_contents, :quantity, from: 0, to: nil

    add_check_constraint :basket_contents, "JSON_TYPE(basket_percentages) = 'array'", name: "basket_contents_basket_percentages_is_array"
    add_check_constraint :basket_contents, "JSON_TYPE(basket_quantities) = 'array'", name: "basket_contents_basket_quantities_is_array"
    add_check_constraint :basket_contents, "JSON_TYPE(basket_size_ids) = 'array'", name: "basket_contents_basket_size_ids_is_array"
    add_check_constraint :basket_contents, "JSON_TYPE(baskets_counts) = 'array'", name: "basket_contents_baskets_counts_is_array"
  end

  private

  def restore_legacy_basket_content_columns
    say_with_time "Rebuilding legacy basket content columns from basket_quantities" do
      connection.select_all("SELECT id, delivery_id, basket_quantities FROM basket_contents").each do |row|
        quantities_by_size = JSON.parse(row.fetch("basket_quantities") || "{}")
        basket_size_ids = quantities_by_size.keys.map(&:to_i).sort
        basket_quantities = basket_size_ids.map { |id| quantities_by_size.fetch(id.to_s) }
        baskets_counts = legacy_baskets_counts(
          basket_content_id: row.fetch("id").to_i,
          delivery_id: row.fetch("delivery_id").to_i,
          basket_size_ids: basket_size_ids)

        connection.execute <<~SQL.squish
          UPDATE basket_contents
          SET distribution_mode = 'manual',
              quantity = #{connection.quote(legacy_total_quantity(basket_quantities, basket_size_ids, baskets_counts))},
              surplus_quantity = 0,
              basket_percentages = #{connection.quote(legacy_percentages(basket_quantities).to_json)},
              basket_size_ids = #{connection.quote(basket_size_ids.to_json)},
              baskets_counts = #{connection.quote(basket_size_ids.map { |id| baskets_counts[id] }.to_json)},
              basket_quantities = #{connection.quote(basket_quantities.to_json)}
          WHERE id = #{row.fetch("id").to_i}
        SQL
      end
    end
  end

  def legacy_baskets_counts(basket_content_id:, delivery_id:, basket_size_ids:)
    return {} if basket_size_ids.empty?

    depot_ids = connection.select_values(<<~SQL)
      SELECT depot_id
      FROM basket_contents_depots
      WHERE basket_content_id = #{basket_content_id}
    SQL
    return basket_size_ids.index_with(0) if depot_ids.empty?

    counts = connection.select_rows(<<~SQL).to_h { |basket_size_id, count| [ basket_size_id.to_i, count.to_i ] }
      SELECT basket_size_id, SUM(quantity)
      FROM baskets
      WHERE delivery_id = #{delivery_id}
        AND state IN ('normal', 'trial', 'forced')
        AND depot_id IN (#{depot_ids.map(&:to_i).join(', ')})
        AND basket_size_id IN (#{basket_size_ids.join(', ')})
      GROUP BY basket_size_id
    SQL

    basket_size_ids.index_with { |id| counts[id] || 0 }
  end

  def legacy_total_quantity(basket_quantities, basket_size_ids, baskets_counts)
    basket_size_ids.zip(basket_quantities).sum do |basket_size_id, quantity|
      baskets_counts[basket_size_id].to_i * quantity.to_f
    end.round(2)
  end

  def legacy_percentages(basket_quantities)
    return [] if basket_quantities.empty?

    total = basket_quantities.sum(&:to_f)
    return Array.new(basket_quantities.size, 0) if total.zero?

    percentages = basket_quantities.map do |quantity|
      ((quantity.to_f / total) * 100).round
    end
    percentages[-1] += 100 - percentages.sum
    percentages
  end
end
