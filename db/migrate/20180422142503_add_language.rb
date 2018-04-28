class AddLanguage < ActiveRecord::Migration[5.2]
  def change
    add_column :members, :language, :string, null: false, default: 'fr'
    add_column :admins, :language, :string, null: false, default: 'fr'
    add_column :distributions, :language, :string, null: false, default: 'fr'
  end
end
