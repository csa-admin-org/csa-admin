class AddExistingACPSharesNumberToMembers < ActiveRecord::Migration[5.2]
  def change
    add_column :members, :existing_acp_shares_number, :integer, null: false, default: 0
  end
end
