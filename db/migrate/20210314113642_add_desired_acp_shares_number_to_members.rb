class AddDesiredACPSharesNumberToMembers < ActiveRecord::Migration[6.1]
  def change
    add_column :members, :desired_acp_shares_number, :integer, default: 0, null: false
  end
end
