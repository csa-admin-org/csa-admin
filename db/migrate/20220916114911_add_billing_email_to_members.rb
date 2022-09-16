class AddBillingEmailToMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :members, :billing_email, :string
  end
end
