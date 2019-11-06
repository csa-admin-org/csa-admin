class AddDeliveryPDFShowPhonesToAcps < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :delivery_pdf_show_phones, :boolean, null: false, default: false
  end
end
