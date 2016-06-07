class AddCarpoolingPhoneToHalfdayWorks < ActiveRecord::Migration
  def change
    add_column :halfday_works, :carpooling_phone, :string
  end
end
