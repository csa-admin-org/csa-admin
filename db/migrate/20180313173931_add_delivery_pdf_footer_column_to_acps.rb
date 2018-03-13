class AddDeliveryPDFFooterColumnToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :delivery_pdf_footer, :text
  end
end
