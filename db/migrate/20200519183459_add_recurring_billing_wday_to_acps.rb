class AddRecurringBillingWdayToAcps < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :recurring_billing_wday, :integer
  end
end
