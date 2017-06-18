class AddEmailsToDistributions < ActiveRecord::Migration[5.1]
  def change
    add_column :distributions, :emails, :string
  end
end
