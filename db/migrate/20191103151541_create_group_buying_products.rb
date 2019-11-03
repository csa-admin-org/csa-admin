class CreateGroupBuyingProducts < ActiveRecord::Migration[6.0]
  def change
    create_table :group_buying_products do |t|
      t.references :producer, foreign_key: { to_table: :group_buying_producers }, null: false, index: true

      t.jsonb :names, :jsonb, default: {}, null: false
      t.decimal :price, scale: 2, precision: 8, null: false
      t.boolean :available, default: true, null: false
    end
  end
end
