# frozen_string_literal: true

class AddThemeToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :theme, :string, default: "system", null: false
  end
end
