class CreateMembers < ActiveRecord::Migration
  def change
    create_table :members do |t|
      t.string :emails, array: true
      t.string :phones, array: true
      t.string :name
      t.string :address
      t.string :zip
      t.string :city

      t.timestamps
    end
  end
end
