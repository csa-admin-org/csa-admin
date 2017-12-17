class AddCarpoolingPhoneToHalfdayWorks < ActiveRecord::Migration[4.2]
  def change
    add_column :halfday_works, :carpooling_phone, :string
  end
end
