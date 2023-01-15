class AddNewslettersAudience < ActiveRecord::Migration[7.0]
  def change
    add_column :newsletters, :audience, :string, null: false
  end
end
