# frozen_string_literal: true

class CreateDeliveryCyclePeriods < ActiveRecord::Migration[8.0]
  def up
    create_table :delivery_cycle_periods do |t|
      t.references :delivery_cycle, null: false, foreign_key: true, index: true
      t.integer :from_fy_month, null: false, default: 1
      t.integer :to_fy_month, null: false, default: 12
      t.integer :results, null: false, default: 0
      t.integer :minimum_gap_in_days
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index [ :delivery_cycle_id, :from_fy_month, :to_fy_month ],
        name: "index_delivery_cycle_periods_on_cycle_and_month_range"
    end

    add_check_constraint :delivery_cycle_periods,
      "from_fy_month BETWEEN 1 AND 12",
      name: "delivery_cycle_periods_from_fy_month_between_1_12"
    add_check_constraint :delivery_cycle_periods,
      "to_fy_month BETWEEN 1 AND 12",
      name: "delivery_cycle_periods_to_fy_month_between_1_12"
    add_check_constraint :delivery_cycle_periods,
      "from_fy_month <= to_fy_month",
      name: "delivery_cycle_periods_from_fy_month_lte_to_fy_month"

    # Backfill periods so that the deliveries selected before/after the migration
    # remain identical:
    # - delivery_cycles.months is a list of calendar months (1..12)
    # - periods are expressed in fiscal-year months (1..12 relative to fiscal year start month)
    #
    # To preserve behavior, we:
    # 1) map calendar months -> fy months
    # 2) create one period per contiguous run of fy months
    say_with_time "Backfill delivery_cycle_periods from delivery_cycles.months" do
      execute <<~SQL.squish
        DELETE FROM delivery_cycle_periods
      SQL

      # Read fiscal year start month once (per-tenant DB)
      start_month =
        select_value(<<~SQL.squish).to_i
          SELECT fiscal_year_start_month
          FROM organizations
          LIMIT 1
        SQL
      start_month = 1 if start_month.zero?

      # Fetch delivery cycles we need to backfill
      delivery_cycles =
        select_all(<<~SQL.squish)
          SELECT id, months, results, minimum_gap_in_days, created_at, updated_at
          FROM delivery_cycles
        SQL

      delivery_cycles.each do |row|
        dc_id = row["id"]
        dc_results = row["results"]
        dc_minimum_gap_in_days = row["minimum_gap_in_days"]
        created_at = row["created_at"]
        updated_at = row["updated_at"]

        months = JSON.parse(row["months"]).map(&:to_i).uniq.sort
        # If months is empty, previous behavior would select nothing.
        raise "No months!" if months.empty?

        fy_months = months.map { |m| (((m - start_month) % 12) + 1) }.uniq.sort

        runs = contiguous_runs(fy_months)
        runs.each do |from_fy_month, to_fy_month|
          minimum_gap_value = dc_minimum_gap_in_days || "NULL"
          execute <<~SQL.squish
            INSERT INTO delivery_cycle_periods
              (delivery_cycle_id, from_fy_month, to_fy_month, results, minimum_gap_in_days, created_at, updated_at)
            VALUES
              (#{dc_id}, #{from_fy_month}, #{to_fy_month}, #{dc_results}, #{minimum_gap_value}, #{quote(created_at)}, #{quote(updated_at)})
          SQL
        end
      end
    end
  end

  def down
    drop_table :delivery_cycle_periods
  end

  private

  def contiguous_runs(sorted_values)
    runs = []
    start_v = sorted_values.first
    prev_v = start_v

    sorted_values.drop(1).each do |v|
      if v == prev_v + 1
        prev_v = v
      else
        runs << [ start_v, prev_v ]
        start_v = v
        prev_v = v
      end
    end

    runs << [ start_v, prev_v ]
    runs
  end
end
