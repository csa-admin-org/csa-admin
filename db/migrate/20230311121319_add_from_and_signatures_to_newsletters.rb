class AddFromAndSignaturesToNewsletters < ActiveRecord::Migration[7.0]
  def change
    add_column :newsletters, :from, :string
    add_column :newsletters, :signatures, :jsonb, default: {}, null: false
  end
end
