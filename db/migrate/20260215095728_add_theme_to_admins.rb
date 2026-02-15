# frozen_string_literal: true

class AddThemeToAdmins < ActiveRecord::Migration[8.0]
  def change
    add_column :admins, :theme, :string, default: "system", null: false
  end
end
