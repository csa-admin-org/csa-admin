class RemoveMembersCountryCodeDefault < ActiveRecord::Migration[6.0]
  def change
    change_column_default :members, :country_code, from: 'CH', to: nil
  end
end
