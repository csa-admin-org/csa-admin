class CreateGroupBuyingProducers < ActiveRecord::Migration[6.0]
  def change
    create_table :group_buying_producers do |t|
      t.string :name, null: false
      t.string :website_url
    end
  end
end
