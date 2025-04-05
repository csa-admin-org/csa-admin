# frozen_string_literal: true

class AddBillingAddressToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :billing_name, :string
    add_column :members, :billing_address, :string
    add_column :members, :billing_city, :string
    add_column :members, :billing_zip, :string
  end
end
