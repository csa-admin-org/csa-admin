# frozen_string_literal: true

class AddIgnoredAtToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :ignored_at, :datetime
  end
end
