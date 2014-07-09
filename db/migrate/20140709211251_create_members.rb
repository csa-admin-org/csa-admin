class CreateMembers < ActiveRecord::Migration
  def change
    create_table :members do |t|
      t.string :emails, array: true
      t.string :phones, array: true
      t.string :title
      t.string :title2
      t.string :name1
      t.string :name2
      t.string :address
      t.string :zip
      t.string :city

      t.timestamps
    end
  end
end
