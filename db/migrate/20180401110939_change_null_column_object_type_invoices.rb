class ChangeNullColumnObjectTypeInvoices < ActiveRecord::Migration[5.2]
  def change
    # Invoice.where(object_type: nil).update_all(object_type: 'Support')

    change_column_null :invoices, :object_type, false
  end
end
