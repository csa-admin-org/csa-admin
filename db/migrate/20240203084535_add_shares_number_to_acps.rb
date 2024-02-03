class AddSharesNumberToAcps < ActiveRecord::Migration[7.1]
  def change
    add_column :acps, :shares_number, :integer

    up_only do
      if Tenant.outside?
        execute "UPDATE acps SET shares_number = 1 WHERE share_price IS NOT NULL"
      end
    end
  end
end
