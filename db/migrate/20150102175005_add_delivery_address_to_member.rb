class AddDeliveryAddressToMember < ActiveRecord::Migration
  def change
    add_column :members, :delivery_address, :string
    add_column :members, :delivery_zip, :string
    add_column :members, :delivery_city, :string
  end
end
