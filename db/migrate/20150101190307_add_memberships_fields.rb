class AddMembershipsFields < ActiveRecord::Migration
  def change
    add_column :memberships, :distribution_basket_price, :integer
    add_column :memberships, :note, :text
  end
end
