class CreateBillingSnapshots < ActiveRecord::Migration[6.0]
  def change
    create_table :billing_snapshots do |t|
      t.timestamps
    end
  end
end
