class AddAnnualFeeToMemberships < ActiveRecord::Migration[6.0]
  def change
    add_column :memberships, :annual_fee, :decimal, precision: 8, scale: 2
  end
end
