class AddEmailFooterAndHalfdayPhoneToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :email_footer, :string
    add_column :acps, :halfday_phone, :string
  end
end
