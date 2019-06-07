class AddMembershipExtraTextsToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :membership_extra_texts, :jsonb, default: {}, null: false
  end
end
