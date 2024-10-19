# frozen_string_literal: true

class RemoveHostAndTenantNameOfOrganizations < ActiveRecord::Migration[8.0]
  def change
    remove_column :organizations, :host
    remove_column :organizations, :tenant_name
  end
end
