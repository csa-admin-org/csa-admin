class AddEmailSignatureToAcps < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :email_signatures, :jsonb, default: {}, null: false
    add_column :acps, :email_footers, :jsonb, default: {}, null: false
  end
end
