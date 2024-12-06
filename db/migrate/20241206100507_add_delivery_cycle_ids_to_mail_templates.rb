# frozen_string_literal: true

class AddDeliveryCycleIdsToMailTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :mail_templates, :delivery_cycle_ids, :json

    add_check_constraint :mail_templates, "JSON_TYPE(delivery_cycle_ids) = 'array'",
      name: "mail_templates_delivery_cycle_ids_is_array"
  end
end
