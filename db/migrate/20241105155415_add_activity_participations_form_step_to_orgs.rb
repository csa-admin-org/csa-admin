# frozen_string_literal: true

class AddActivityParticipationsFormStepToOrgs < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :activity_participations_form_step, :integer, default: 1, null: false
  end
end
