class AddRenewalColumnsToMemberships < ActiveRecord::Migration[6.0]
  def change
    add_column :memberships, :renewed_at, :datetime
    add_column :memberships, :renewal_opened_at, :datetime
    add_column :memberships, :renewal_note, :text
    rename_column :memberships, :annual_fee, :renewal_annual_fee
  end
end
