# frozen_string_literal: true

class AddPostmarkCredentialsToOrg < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :postmark_server_token, :string
    add_column :organizations, :postmark_server_id, :string
  end
end
