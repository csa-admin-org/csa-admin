class AddAbsencesBilledToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :absences_billed, :boolean, default: true, null: false
  end
end
