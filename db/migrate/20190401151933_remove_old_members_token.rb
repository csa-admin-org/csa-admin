# frozen_string_literal: true

class RemoveOldMembersToken < ActiveRecord::Migration[5.2]
  def change
    remove_column :members, :token
  end
end
