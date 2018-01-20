class AddFiscalYearStartMonthToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :fiscal_year_start_month, :integer, null: false, default: 1
  end
end
