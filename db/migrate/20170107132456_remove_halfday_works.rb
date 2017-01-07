class RemoveHalfdayWorks < ActiveRecord::Migration[5.0]
  def change
    drop_table :halfday_works
    drop_table :halfday_work_dates
  end
end
