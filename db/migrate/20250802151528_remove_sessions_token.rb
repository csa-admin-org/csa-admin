# frozen_string_literal: true

class RemoveSessionsToken < ActiveRecord::Migration[8.1]
  def change
    remove_column :sessions, :token, :string
  end
end
