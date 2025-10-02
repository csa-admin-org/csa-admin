# frozen_string_literal: true

class AddOriginToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :origin, :string, null: false, default: "manual"
  end
end
