class DropGroupBuying < ActiveRecord::Migration[7.0]
  def change
    remove_column :acps, :group_buying_email
    remove_column :acps, :group_buying_terms_of_service_urls
    remove_column :acps, :group_buying_invoice_infos

    drop_table :group_buying_order_items
    drop_table :group_buying_orders
    drop_table :group_buying_products
    drop_table :group_buying_producers
    drop_table :group_buying_deliveries
  end
end
