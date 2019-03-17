class AddAdminToSessions < ActiveRecord::Migration[5.2]
  def up
    add_reference :sessions, :admin, foreign_key: true, index: true

    execute <<-SQL
      ALTER TABLE sessions ADD CONSTRAINT owner_set CHECK (
        (
          (member_id is not null)::integer +
          (admin_id is not null)::integer
        ) = 1
      );
    SQL
  end

  def down
    execute 'ALTER TABLE sessions DROP CONSTRAINT owner_set'

    remove_colum :sessions, :admin_id
  end
end
