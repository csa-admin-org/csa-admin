class RemoveMembershipExtraTextsFromAcps < ActiveRecord::Migration[7.0]
  def change
    remove_column :acps, :membership_extra_texts
  end
end
