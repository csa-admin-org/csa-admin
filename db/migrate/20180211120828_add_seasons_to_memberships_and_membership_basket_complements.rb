class AddSeasonsToMembershipsAndMembershipBasketComplements < ActiveRecord::Migration[5.2]
  def change
    add_column :memberships, :seasons, :string, array: true, null: false, default: %w[summer winter]
    add_column :memberships_basket_complements, :seasons, :string, array: true, null: false, default: %w[summer winter]
  end
end
