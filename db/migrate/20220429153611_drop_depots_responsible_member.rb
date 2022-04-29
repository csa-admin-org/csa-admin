class DropDepotsResponsibleMember < ActiveRecord::Migration[7.0]
  def change
    remove_reference(:depots, :responsible_member, foreign_key: { to_table: :members })
  end
end
