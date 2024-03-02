class AddSepaColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :acps, :sepa_creditor_identifier, :string

    add_column :members, :iban, :string
    add_column :members, :sepa_mandate_id, :string
    add_column :members, :sepa_mandate_signed_on, :date
  end
end
