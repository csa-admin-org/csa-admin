# frozen_string_literal: true

class AddBillableToBaskets < ActiveRecord::Migration[7.1]
  def change
    add_column :baskets, :billable, :boolean, default: true, null: false

    up_only do
      if Tenant.inside?
        org = Organization.find_by(tenant_name: Tenant.current)
        unless org.absences_billed?
          execute "UPDATE baskets SET billable = false WHERE state = 'absent'"
        end
      end
    end
  end
end
