# frozen_string_literal: true

class RenameAddressToStreet < ActiveRecord::Migration[8.1]
  def change
    rename_column :depots, :address, :street
    rename_column :members, :address, :street
    rename_column :members, :billing_address, :billing_street
    rename_column :organizations, :creditor_address, :creditor_street
  end
end
