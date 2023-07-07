class AddRequiredACPSharesNumberToMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :members, :required_acp_shares_number, :integer
  end
end
