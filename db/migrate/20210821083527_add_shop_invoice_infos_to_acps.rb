class AddShopInvoiceInfosToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :shop_invoice_infos, :jsonb, default: {}, null: false
  end
end
