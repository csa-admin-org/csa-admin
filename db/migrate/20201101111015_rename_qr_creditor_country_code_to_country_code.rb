class RenameQRCreditorCountryCodeToCountryCode < ActiveRecord::Migration[6.0]
  def change
    rename_column :acps, :qr_creditor_country_code, :country_code
  end
end
