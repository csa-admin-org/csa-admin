class MakeMembersTokenOptional < ActiveRecord::Migration[5.2]
  def change
    change_column_null :members, :token, true
  end
end
