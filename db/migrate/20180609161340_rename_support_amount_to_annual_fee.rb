class RenameSupportAmountToAnnualFee < ActiveRecord::Migration[5.2]
  def change
    rename_column :invoices, :support_amount, :annual_fee

    Invoice.where(object_type: 'Support').update_all(object_type: 'AnnualFee')
  end
end
