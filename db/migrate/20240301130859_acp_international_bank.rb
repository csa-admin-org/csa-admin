class ACPInternationalBank < ActiveRecord::Migration[7.1]
  def change
    rename_column :acps, :qr_iban, :iban
    rename_column :acps, :qr_bank_reference, :bank_reference
    rename_column :acps, :qr_creditor_name, :creditor_name
    rename_column :acps, :qr_creditor_address, :creditor_address
    rename_column :acps, :qr_creditor_city, :creditor_city
    rename_column :acps, :qr_creditor_zip, :creditor_zip
  end
end
