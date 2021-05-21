class AddAbsenceAnnouncementLimitInDaysToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :absence_notice_period_in_days, :integer, default: 7, null: false
  end
end
