class AddReviewSentAtToActivityParticipations < ActiveRecord::Migration[5.2]
  def change
    add_column :activity_participations, :review_sent_at, :timestamp
  end
end
