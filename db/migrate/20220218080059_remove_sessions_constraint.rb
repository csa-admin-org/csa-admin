class RemoveSessionsConstraint < ActiveRecord::Migration[6.1]
  def up
    execute 'ALTER TABLE sessions DROP CONSTRAINT IF EXISTS owner_set'
  end

  def down
    execute <<-SQL
      ALTER TABLE sessions ADD CONSTRAINT owner_set CHECK (
        (
          (member_id is not null)::integer +
          (admin_id is not null)::integer
        ) = 1
      );
    SQL
  end
end
