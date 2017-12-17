class AddParticipantsLimitToHalfdayWorkDates < ActiveRecord::Migration[4.2]
  def change
    add_column :halfday_work_dates, :participants_limit, :integer
  end
end
