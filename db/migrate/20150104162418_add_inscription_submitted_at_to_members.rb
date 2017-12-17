class AddInscriptionSubmittedAtToMembers < ActiveRecord::Migration[4.2]
  def change
    add_column :members, :inscription_submitted_at, :datetime
    add_index :members, :inscription_submitted_at
  end
end
