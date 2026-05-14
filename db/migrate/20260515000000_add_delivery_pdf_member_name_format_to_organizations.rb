# frozen_string_literal: true

class AddDeliveryPDFMemberNameFormatToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :delivery_pdf_member_name_format, :string, default: "none", null: false
  end
end
