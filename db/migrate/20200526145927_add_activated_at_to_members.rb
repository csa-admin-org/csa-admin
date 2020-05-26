class AddActivatedAtToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :activated_at, :datetime
  end
end
