# frozen_string_literal: true

class AddUpdatedAtIndexesToBasketsAndActivityParticipations < ActiveRecord::Migration[8.1]
  def change
    add_index :baskets, :updated_at
    add_index :baskets, [ :membership_id, :updated_at ]
    add_index :activity_participations, :updated_at
    add_index :activity_participations, [ :member_id, :updated_at ]
  end
end
