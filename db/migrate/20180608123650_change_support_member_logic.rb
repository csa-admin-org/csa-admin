class ChangeSupportMemberLogic < ActiveRecord::Migration[5.2]
  def change
    change_column_null :members, :support_price, true
    change_column_default :members, :support_price, nil
    change_column_null :acps, :support_price, true
    change_column_default :acps, :support_price, nil

    Member.inactive.find_each do |member|
      if member.support_member?
        member.update_column(:state, 'support')
      else
        member.update_column(:support_price, nil)
      end
    end

    remove_column :members, :support_member
  end
end
