class AddResponsibleMemberIdToDistributions < ActiveRecord::Migration[5.2]
  def change
    add_reference :distributions, :responsible_member, foreign_key: { to_table: :members }
  end
end
