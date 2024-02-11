class AddStateAndAbsenceIdToBaskets < ActiveRecord::Migration[7.1]
  def change
    add_column :baskets, :state, :string, default: "normal", null: false
    add_reference :baskets, :absence, foreign_key: true, index: true
    rename_column :memberships, :delivered_baskets_count, :past_baskets_count
    remove_column :baskets, :absent, :boolean, default: false, null: false
    remove_column :baskets, :trial, :boolean, default: false, null: false

    up_only do
      Membership.find_each { |m| m.save!(validate: false) }
    end
  end
end
