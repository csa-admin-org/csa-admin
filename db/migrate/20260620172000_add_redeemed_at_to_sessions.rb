# frozen_string_literal: true

class AddRedeemedAtToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :redeemed_at, :datetime
  end
end
