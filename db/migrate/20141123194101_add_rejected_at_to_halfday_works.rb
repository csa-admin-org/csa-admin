class AddRejectedAtToHalfdayWorks < ActiveRecord::Migration
  def change
    add_column :halfday_works, :rejected_at, :datetime
    add_index :halfday_works, :rejected_at
  end
end
