class RemoveParanoiaFromPayments < ActiveRecord::Migration[6.1]
  def change
    execute 'DELETE FROM payments WHERE deleted_at IS NOT NULL'
    remove_column :payments, :deleted_at
  end
end
