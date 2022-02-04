class CreateBaskets < ActiveRecord::Migration[5.1]
  def change
    create_table :baskets do |t|
      t.references :membership, foreign_key: true, null: false, index: true
      t.references :delivery, foreign_key: true, null: false, index: true
      t.references :basket_size, foreign_key: true, null: false, index: true
      t.references :distribution, foreign_key: true, null: false, index: true

      t.decimal :basket_price, scale: 3, precision: 8, default: 0, null: false
      t.decimal :distribution_price, scale: 2, precision: 8, default: 0, null: false

      t.boolean :trial, default: false, null: false
      t.boolean :absent, default: false, null: false

      t.timestamps
    end
    add_index :baskets, [:membership_id, :delivery_id], unique: true

    add_column :memberships, :baskets_count, :integer, default: 0, null: false



    change_column_default :memberships, :halfday_works_annual_price, 0
    change_column_default :memberships, :annual_halfday_works, 0
    Membership.where(halfday_works_annual_price: nil).update_all(halfday_works_annual_price: 0)
    Membership.where(annual_halfday_works: nil).update_all(annual_halfday_works: 0)
    change_column_null :memberships, :halfday_works_annual_price, false
    change_column_null :memberships, :annual_halfday_works, false
    change_column_null :memberships, :basket_size_id, true
    change_column_null :memberships, :distribution_id, true
  end
end
