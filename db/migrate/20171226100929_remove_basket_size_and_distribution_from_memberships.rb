class RemoveBasketSizeAndDistributionFromMemberships < ActiveRecord::Migration[5.1]
  def change
    remove_column :memberships, :basket_size_id
    remove_column :memberships, :distribution_id
  end
end
