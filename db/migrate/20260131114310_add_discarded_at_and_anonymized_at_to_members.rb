# frozen_string_literal: true

class AddDiscardedAtAndAnonymizedAtToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :discarded_at, :datetime
    add_column :members, :anonymized_at, :datetime

    add_index :members, :discarded_at
    add_index :members, :anonymized_at
  end
end
