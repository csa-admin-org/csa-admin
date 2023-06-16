class AddDeliveryNoteToMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :members, :delivery_note, :string
  end
end
