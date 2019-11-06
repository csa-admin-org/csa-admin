class EnforceTimestampsPresenceOnGroupBuyingTables < ActiveRecord::Migration[6.0]
  def change
    change_column_null :group_buying_deliveries, :created_at, false
    change_column_null :group_buying_deliveries, :updated_at, false
    change_column_null :group_buying_producers, :created_at, false
    change_column_null :group_buying_producers, :updated_at, false
    change_column_null :group_buying_products, :created_at, false
    change_column_null :group_buying_products, :updated_at, false
  end
end
