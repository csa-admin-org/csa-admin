class AddACPSharesInfoToMembers < ActiveRecord::Migration[5.2]
  def change
    add_column :members, :acp_shares_info, :string
  end
end
