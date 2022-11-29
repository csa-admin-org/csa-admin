class AddFormDetailsColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :basket_sizes, :form_details, :string
    add_column :basket_complements, :form_details, :string
  end
end
