# frozen_string_literal: true

class AddNameToMembers < ActiveRecord::Migration[5.1]
  def change
    add_column :members, :name, :string
  end
end
