class AddQRBankReferenceToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :qr_bank_reference, :string
  end
end
