class AddMembersWaitingFields < ActiveRecord::Migration[4.2]
  def change
    add_column :members, :waiting_basket_id, :integer
    add_column :members, :waiting_distribution_id, :integer

    add_index :members, :waiting_basket_id
    add_index :members, :waiting_distribution_id

    Member.waiting.includes(:current_membership).each do |member|
      next unless member.current_membership
      member.update!(
        waiting_basket_id: member.current_membership.basket_id,
        waiting_distribution_id: member.current_membership.distribution_id,
      )
      member.current_membership.delete
    end
  end
end
