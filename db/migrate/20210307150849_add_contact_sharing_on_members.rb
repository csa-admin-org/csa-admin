class AddContactSharingOnMembers < ActiveRecord::Migration[6.1]
  def change
    add_column :members, :contact_sharing, :boolean, default: false, null: false
  end
end
