class AddShopDeliveryPDFFooterToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :shop_delivery_pdf_footers, :jsonb, default: {}, null: false
  end
end
