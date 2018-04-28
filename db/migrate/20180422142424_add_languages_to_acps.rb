class AddLanguagesToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :languages, :string, array: true, null: false, default: %w[fr]
  end
end
