class AddTimestampsToGroupBuyingsTables < ActiveRecord::Migration[6.0]
  def change
    add_column :group_buying_deliveries, :created_at, :datetime
    add_column :group_buying_deliveries, :updated_at, :datetime
    add_column :group_buying_producers, :created_at, :datetime
    add_column :group_buying_producers, :updated_at, :datetime
    add_column :group_buying_products, :created_at, :datetime
    add_column :group_buying_products, :updated_at, :datetime
  end
end
