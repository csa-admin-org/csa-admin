# frozen_string_literal: true

class NullifyZeroAnnualFeeForInactiveMembers < ActiveRecord::Migration[8.0]
  def up
    Tenant.switch_each do
      Member.where(state: "inactive", annual_fee: 0).update_all(annual_fee: nil)
    end
  end
end
