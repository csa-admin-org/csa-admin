# frozen_string_literal: true

class RemoveMembersSubdomain < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :members_subdomain, :string
  end
end
