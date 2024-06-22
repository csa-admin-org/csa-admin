# frozen_string_literal: true

class AddNotificationsToAdmins < ActiveRecord::Migration[5.2]
  def change
    add_column :admins, :notifications, :string, array: true, default: [], null: false
  end
end
