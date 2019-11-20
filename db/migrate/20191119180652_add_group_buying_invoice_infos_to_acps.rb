class AddGroupBuyingInvoiceInfosToAcps < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :group_buying_invoice_infos, :jsonb, default: {}, null: false
  end
end
