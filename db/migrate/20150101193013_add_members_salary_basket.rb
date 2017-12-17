class AddMembersSalaryBasket < ActiveRecord::Migration[4.2]
  def change
    add_column :members, :salary_basket, :boolean, default: false
  end
end
