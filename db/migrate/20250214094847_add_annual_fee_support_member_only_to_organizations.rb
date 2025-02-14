# frozen_string_literal: true

class AddAnnualFeeSupportMemberOnlyToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :annual_fee_support_member_only, :boolean, null: false, default: false
  end
end
