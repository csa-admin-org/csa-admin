class AddTrialBasketsCountToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :trial_basket_count, :integer, default: 0, null: false
  end
end
