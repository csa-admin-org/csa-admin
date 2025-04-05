# frozen_string_literal: true

class RemoveDeliveryAddressFromMembers < ActiveRecord::Migration[8.1]
  def change
    remove_column :members, :delivery_address, :string
    remove_column :members, :delivery_city, :string
    remove_column :members, :delivery_zip, :string
  end
end
