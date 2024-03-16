class DropBillingYearDivisionInMembers < ActiveRecord::Migration[7.1]
  def change
    remove_column :members, :billing_year_division, :integer, default: 1, null: false
  end
end
