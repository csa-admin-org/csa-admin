class AddIcalendarAuthTokenToACP < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :icalendar_auth_token, :string
  end
end
