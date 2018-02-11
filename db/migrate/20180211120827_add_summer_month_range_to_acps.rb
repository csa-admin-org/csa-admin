class AddSummerMonthRangeToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :summer_month_range, :int4range
  end
end
