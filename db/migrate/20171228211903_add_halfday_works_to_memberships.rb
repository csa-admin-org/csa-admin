class AddHalfdayWorksToMemberships < ActiveRecord::Migration[5.1]
  def change
    add_column :memberships, :halfday_works, :integer, default: 0, null: false
    add_column :memberships, :validated_halfday_works, :integer, default: 0, null: false
  end
end
