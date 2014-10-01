class CreateDistributions < ActiveRecord::Migration
  def change
    create_table :distributions do |t|
      t.string :name
      t.string :address
      t.string :zip
      t.string :city

      t.timestamps
    end

    add_column :members, :distribution_id, :string
    add_index  :members, :distribution_id
  end
end
