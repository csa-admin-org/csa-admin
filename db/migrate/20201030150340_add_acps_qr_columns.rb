class AddAcpsQRColumns < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :qr_iban, :string
    add_column :acps, :qr_creditor_name, :string, limit: 70
    add_column :acps, :qr_creditor_address, :string, limit: 70
    add_column :acps, :qr_creditor_city, :string, limit: 35
    add_column :acps, :qr_creditor_zip, :string, limit: 16
    add_column :acps, :qr_creditor_country_code, :string, limit: 2
    add_column :acps, :currency_code, :string, limit: 3, default: 'CHF'
    add_column :members, :country_code, :string, limit: 2, default: 'CH'
  end
end
