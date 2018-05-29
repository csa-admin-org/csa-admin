class RemoveInscriptionSubmittedAtColumns < ActiveRecord::Migration[5.2]
  def change
    remove_column :members, :inscription_submitted_at
  end
end
