class ChangeMemberFields < ActiveRecord::Migration
  def change
    change_column :members, :gribouille, :boolean, default: nil, null: true

    rename_column :members, :waiting_from, :waiting_started_at
    add_index :members, :waiting_started_at

    Member.where('id <= 135 OR id IN (165, 166)').update_all(created_at: Date.new(2014))
  end
end
