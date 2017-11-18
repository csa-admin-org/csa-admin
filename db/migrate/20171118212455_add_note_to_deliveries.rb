class AddNoteToDeliveries < ActiveRecord::Migration[5.1]
  def change
    add_column :deliveries, :note, :text
  end
end
