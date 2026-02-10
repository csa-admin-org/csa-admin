# frozen_string_literal: true

class AddLocalCurrencyMembershipAnnualFeeOnlyToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :local_currency_membership_annual_fee_only, :boolean, default: true
  end
end
