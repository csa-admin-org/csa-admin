# frozen_string_literal: true

class AddShopInvoicePeriodToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :shop_invoice_period, :string
  end
end
