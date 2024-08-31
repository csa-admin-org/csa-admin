# frozen_string_literal: true

class RenameAcpsToOrganizations < ActiveRecord::Migration[7.2]
  def change
    rename_table :acps, :organizations
  end
end
