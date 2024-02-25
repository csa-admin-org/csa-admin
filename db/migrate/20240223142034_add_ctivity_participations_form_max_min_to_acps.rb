class AddCtivityParticipationsFormMaxMinToAcps < ActiveRecord::Migration[7.1]
  def change
    add_column :acps, :activity_participations_form_min, :integer
    add_column :acps, :activity_participations_form_max, :integer
    add_column :acps, :activity_participations_form_details, :jsonb, default: {}, null: false
    add_column :members, :waiting_activity_participations_demanded_annually, :integer
  end
end
