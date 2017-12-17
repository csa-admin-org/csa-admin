class AddMembershipsFields < ActiveRecord::Migration[4.2]
  def change
    add_column :memberships, :distribution_basket_price, :integer
    add_column :memberships, :note, :text
  end
end
