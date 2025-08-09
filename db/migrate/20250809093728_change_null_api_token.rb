# frozen_string_literal: true

class ChangeNullAPIToken < ActiveRecord::Migration[8.1]
  def change
    change_column_null :organizations, :api_token, false
  end
end
