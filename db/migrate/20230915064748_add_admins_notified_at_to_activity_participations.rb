class AddAdminsNotifiedAtToActivityParticipations < ActiveRecord::Migration[7.0]
  def change
    add_column :activity_participations, :admins_notified_at, :datetime
  end
end
