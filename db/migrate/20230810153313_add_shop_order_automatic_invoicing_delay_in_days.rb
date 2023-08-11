class AddShopOrderAutomaticInvoicingDelayInDays < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :shop_order_automatic_invoicing_delay_in_days, :integer
  end
end
