# frozen_string_literal: true

class AddBasketContentDeliveryPDFVisibleToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :basket_content_delivery_pdf_visible, :boolean, default: false, null: false
  end
end
