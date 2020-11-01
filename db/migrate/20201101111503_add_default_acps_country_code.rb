class AddDefaultAcpsCountryCode < ActiveRecord::Migration[6.0]
  def change
    change_column_default :acps, :country_code, from: nil, to: 'CH'
    change_column_null :acps, :country_code, false
  end
end
