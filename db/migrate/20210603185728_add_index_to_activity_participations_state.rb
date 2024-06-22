# frozen_string_literal: true

class AddIndexToActivityParticipationsState < ActiveRecord::Migration[6.1]
  def change
    add_index :activity_participations, :state
  end
end
