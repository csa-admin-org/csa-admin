class ChangeColumnsNullOnMemberships < ActiveRecord::Migration[5.2]
  def change
    change_column_null :memberships, :basket_size_id, false
    change_column_null :memberships, :distribution_id, false
    change_column_null :memberships, :basket_price, false
    change_column_null :memberships, :distribution_price, false
  end
end
