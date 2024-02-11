class AddBillableToBaskets < ActiveRecord::Migration[7.1]
  def change
    add_column :baskets, :billable, :boolean, default: true, null: false

    up_only do
      if Tenant.inside?
        acp = ACP.find_by(tenant_name: Tenant.current)
        unless acp.absences_billed?
          execute "UPDATE baskets SET billable = false WHERE state = 'absent'"
        end
      end
    end
  end
end
