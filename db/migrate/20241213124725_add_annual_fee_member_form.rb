# frozen_string_literal: true

class AddAnnualFeeMemberForm < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :annual_fee_member_form, :boolean, default: false, null: false
  end
end
