class ChangeInvoicesDefaultState < ActiveRecord::Migration[6.1]
  def change
    change_column_default :invoices, :state, from: 'not_sent', to: 'processing'
  end
end
