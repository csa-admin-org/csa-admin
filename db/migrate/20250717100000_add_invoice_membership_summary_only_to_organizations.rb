# frozen_string_literal: true

class AddInvoiceMembershipSummaryOnlyToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :invoice_membership_summary_only, :boolean, default: false, null: false
  end
end
