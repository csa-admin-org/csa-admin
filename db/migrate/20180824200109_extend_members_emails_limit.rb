class ExtendMembersEmailsLimit < ActiveRecord::Migration[5.2]
  def change
    change_column :members, :emails, :string, limit: nil
  end
end
