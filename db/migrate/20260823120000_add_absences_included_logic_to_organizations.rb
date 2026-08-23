# frozen_string_literal: true

class AddAbsencesIncludedLogicToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :absences_included_logic, :text,
      default: Organization.absences_included_logic_default, null: false
  end
end
