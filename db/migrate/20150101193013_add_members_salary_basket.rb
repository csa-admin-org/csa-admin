class AddMembersSalaryBasket < ActiveRecord::Migration
  def change
    add_column :members, :salary_basket, :boolean, default: false
  end
end
