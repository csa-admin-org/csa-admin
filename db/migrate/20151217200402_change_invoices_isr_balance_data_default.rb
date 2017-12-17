class ChangeInvoicesIsrBalanceDataDefault < ActiveRecord::Migration[4.2]
  def change
    change_column_default :invoices, :isr_balance_data, {}
    Invoice.where(isr_balance_data: nil).update_all(isr_balance_data: {})
    change_column_null :invoices, :isr_balance_data, false
  end
end
