# frozen_string_literal: true

class AcpDropDeliveryPDFShowPhones < ActiveRecord::Migration[7.1]
  def change
    remove_column :acps, :delivery_pdf_show_phones, :boolean, default: false, null: false
  end
end
