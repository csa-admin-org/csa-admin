class ChangeColumnDefaultAnnualHalfdayWorksOnMemberships < ActiveRecord::Migration[5.2]
  def change
    change_column_default :memberships, :annual_halfday_works, nil
  end
end
