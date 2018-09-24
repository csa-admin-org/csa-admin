class AddCarpoolingCityToHalfdayParticipations < ActiveRecord::Migration[5.2]
  def change
    add_column :halfday_participations, :carpooling_city, :string
  end
end
