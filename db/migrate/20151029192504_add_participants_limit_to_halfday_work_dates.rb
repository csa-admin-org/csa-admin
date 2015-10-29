class AddParticipantsLimitToHalfdayWorkDates < ActiveRecord::Migration
  def change
    add_column :halfday_work_dates, :participants_limit, :integer
  end
end
