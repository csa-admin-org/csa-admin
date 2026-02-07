# frozen_string_literal: true

class AddPrevisionalInvoicingAmountsToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :previsional_invoicing_amounts, :json, default: {}, null: false
  end
end
