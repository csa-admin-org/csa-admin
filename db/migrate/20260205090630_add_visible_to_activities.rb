# frozen_string_literal: true

class AddVisibleToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :visible, :boolean, default: true, null: false
  end
end
