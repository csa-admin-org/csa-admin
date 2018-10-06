class AddSessionIdToHalfdayParticipationsAndAbsences < ActiveRecord::Migration[5.2]
  def change
    add_reference :halfday_participations, :session, index: false
    add_reference :absences, :session, index: false
  end
end
