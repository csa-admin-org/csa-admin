# frozen_string_literal: true

class AddMemberFormDepotMapToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :member_form_depot_map, :boolean, default: false, null: false
  end
end
