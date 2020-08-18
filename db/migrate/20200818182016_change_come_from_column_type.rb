class ChangeComeFromColumnType < ActiveRecord::Migration[6.0]
  def change
    change_column :members, :come_from, :text
  end
end
