# frozen_string_literal: true

class AddMoreDiscardedAt < ActiveRecord::Migration[7.1]
  def change
    add_column :depots, :discarded_at, :datetime
    add_index :depots, :discarded_at

    add_column :basket_sizes, :discarded_at, :datetime
    add_index :basket_sizes, :discarded_at

    add_column :basket_complements, :discarded_at, :datetime
    add_index :basket_complements, :discarded_at

    add_column :delivery_cycles, :discarded_at, :datetime
    add_index :delivery_cycles, :discarded_at
  end
end
