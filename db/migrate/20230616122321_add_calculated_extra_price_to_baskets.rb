class AddCalculatedExtraPriceToBaskets < ActiveRecord::Migration[7.0]
  def change
    rename_column :baskets, :price_extra, :calculated_price_extra
    add_column :baskets, :price_extra, :decimal, scale: 2, precision: 8, default: 0, null: false

    reversible do |dir|
      dir.up do
        Membership.find_each do |membership|
          unless membership.basket_price_extra.zero?
            membership.baskets.update_all price_extra: membership.basket_price_extra
          end
        end
      end
    end
  end
end
