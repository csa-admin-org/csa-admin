# frozen_string_literal: true

class AddForceAnnualFormulaToMemberships < ActiveRecord::Migration[8.1]
  def change
    change_table :memberships, bulk: true do |t|
      t.boolean :force_absences_included_annually, default: false, null: false
      t.boolean :force_activity_participations_demanded_annually, default: false, null: false
    end
  end
end
