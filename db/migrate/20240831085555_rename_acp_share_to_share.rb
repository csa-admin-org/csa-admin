# frozen_string_literal: true

class RenameAcpShareToShare < ActiveRecord::Migration[7.2]
  def change
    rename_column :basket_sizes, :acp_shares_number, :shares_number
    rename_column :invoices, :acp_shares_number, :shares_number
    rename_column :members, :acp_shares_info, :shares_info
    rename_column :members, :existing_acp_shares_number, :existing_shares_number
    rename_column :members, :desired_acp_shares_number, :desired_shares_number
    rename_column :members, :required_acp_shares_number, :required_shares_number

    up_only do
      if Tenant.inside?
        Invoice.where(entity_type: "ACPShare").update_all(entity_type: "Share")
      end
    end
  end
end
