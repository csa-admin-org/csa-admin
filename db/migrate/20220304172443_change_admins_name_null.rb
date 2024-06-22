# frozen_string_literal: true

class ChangeAdminsNameNull < ActiveRecord::Migration[6.1]
  def change
    change_column_null :admins, :name, false
  end
end
