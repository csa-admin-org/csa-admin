class AddInscriptionSubmittedAtToMembers < ActiveRecord::Migration
  def change
    add_column :members, :inscription_submitted_at, :datetime
    add_index :members, :inscription_submitted_at
  end
end
