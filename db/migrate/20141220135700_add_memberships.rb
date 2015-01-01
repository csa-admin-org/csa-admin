class AddMemberships < ActiveRecord::Migration
  def change
    remove_index :members, :distribution_id
    remove_column :members, :distribution_id, :integer

    remove_column :members, :name, :string, null: false
    add_column :members, :first_name, :string, null: false
    add_column :members, :last_name, :string, null: false

    change_column :members, :emails, :string
    change_column :members, :phones, :string

    add_column :members, :support_member, :boolean, null: false
    add_column :members, :waiting_started_at, :datetime
    add_column :members, :billing_interval, :string, null: false
    add_column :members, :food_note, :text
    add_column :members, :note, :text
    add_column :members, :validator_id, :integer
    add_column :members, :validated_at, :datetime

    add_column :distributions, :basket_price, :decimal, scale: 2, precision: 8, null: false

    create_table :baskets do |t|
      t.string :name, null: false
      t.integer :year, null: false
      t.decimal :annual_price, scale: 2, precision: 8, null: false
      t.integer :annual_halfday_works, null: false

      t.timestamps
    end

    create_table :memberships do |t|
      t.belongs_to :basket, index: true, null: false
      t.belongs_to :distribution, index: true, null: false
      t.belongs_to :member, index: true, null: false
      t.belongs_to :billing_member, index: true, type: 'Member'

      t.decimal :annual_price, scale: 2, precision: 8
      t.integer :annual_halfday_works

      t.date :started_on, null: false
      t.date :ended_on, null: false

      t.timestamps
    end
    add_index :memberships, :started_on
    add_index :memberships, :ended_on
  end
end
