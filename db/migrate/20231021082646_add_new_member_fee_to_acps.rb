class AddNewMemberFeeToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :new_member_fee, :decimal, precision: 8, scale: 2
    add_column :acps, :new_member_fee_descriptions, :jsonb, default: {}, null: false
  end
end
