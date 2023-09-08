class ClearAbsencesNote < ActiveRecord::Migration[7.0]
  def change
    execute "UPDATE absences SET note = NULL"
  end
end
