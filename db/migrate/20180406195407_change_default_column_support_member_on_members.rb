class ChangeDefaultColumnSupportMemberOnMembers < ActiveRecord::Migration[5.2]
  def change
    change_column_default :members, :support_member, false
  end
end
