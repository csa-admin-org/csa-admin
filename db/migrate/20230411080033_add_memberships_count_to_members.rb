class AddMembershipsCountToMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :members, :memberships_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        Member.find_each do |member|
          Member.reset_counters(member.id, :memberships)
        end
      end
    end
  end
end
