# frozen_string_literal: true

class AddDeliveryPDFMemberOrderModeToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :delivery_pdf_member_order_mode, :string, default: "name_asc", null: false
  end
end
