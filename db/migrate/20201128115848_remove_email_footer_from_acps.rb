class RemoveEmailFooterFromAcps < ActiveRecord::Migration[6.0]
  def change
    remove_column :acps, :email_footer
  end
end
