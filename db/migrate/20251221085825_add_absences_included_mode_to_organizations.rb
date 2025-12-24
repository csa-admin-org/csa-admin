# frozen_string_literal: true

class AddAbsencesIncludedModeToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :absences_included_mode, :string, default: "provisional_absence", null: false
    add_column :organizations, :absences_included_reminder_weeks_before, :integer, default: 4, null: false
  end
end
