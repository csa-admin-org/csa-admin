# frozen_string_literal: true

class AddAPITokenToOrg < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :api_token, :string
  end
end
