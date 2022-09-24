class RemoveIsrACPColumns < ActiveRecord::Migration[7.0]
  def change
    remove_column :acps, :ccp
    remove_column :acps, :isr_identity
    remove_column :acps, :isr_payment_for
    remove_column :acps, :isr_in_favor_of
    rename_column :payments, :isr_data, :fingerprint
  end
end
