# frozen_string_literal: true

class AddMemberFormDeliveryCycleLabelsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :member_form_delivery_cycle_labels, :json, default: {}, null: false
  end
end
