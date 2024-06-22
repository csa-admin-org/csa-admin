# frozen_string_literal: true

class AddNoteToActivityParticipations < ActiveRecord::Migration[7.0]
  def change
    add_column :activity_participations, :note, :text
  end
end
