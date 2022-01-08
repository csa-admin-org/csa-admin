class AddAbsenceExtraTextsToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :absence_extra_text_only, :boolean, default: false, null: false
  end
end
