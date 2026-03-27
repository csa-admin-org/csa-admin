# frozen_string_literal: true

class AddNotifiedAtToAbsences < ActiveRecord::Migration[8.1]
  def change
    add_column :absences, :admins_notified_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE absences SET admins_notified_at = created_at
        SQL
      end
    end
  end
end
