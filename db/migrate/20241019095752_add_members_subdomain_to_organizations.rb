# frozen_string_literal: true

class AddMembersSubdomainToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :members_subdomain, :string

    up_only do
      if Tenant.inside?
        host = Organization.instance.email_default_host
        subdomain = URI.parse(host).host.split(".").first
        Organization.instance.update!(members_subdomain: subdomain)
      end
    end

    remove_column :organizations, :email_default_host
    change_column_null :organizations, :members_subdomain, false
    change_column_null :organizations, :email_default_from, false
  end
end
