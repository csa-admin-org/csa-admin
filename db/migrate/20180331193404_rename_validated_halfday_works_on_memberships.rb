class RenameValidatedHalfdayWorksOnMemberships < ActiveRecord::Migration[5.2]
  def change
    rename_column :memberships, :validated_halfday_works, :recognized_halfday_works

    # Membership.find_each(&:update_recognized_halfday_works!)
  end
end
