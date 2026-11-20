# frozen_string_literal: true

class AddDeliveryBasketCountsIncludeAbsencesToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :delivery_basket_counts_include_absences, :boolean, default: false, null: false
  end
end
