# frozen_string_literal: true

class AddDeletedAtToAdmins < ActiveRecord::Migration[6.0]
  def change
    add_column :admins, :deleted_at, :timestamp
  end
end
