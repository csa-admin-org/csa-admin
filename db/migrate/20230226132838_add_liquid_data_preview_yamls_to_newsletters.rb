class AddLiquidDataPreviewYamlsToNewsletters < ActiveRecord::Migration[7.0]
  def change
    add_column :newsletters, :liquid_data_preview_yamls, :jsonb, default: {}, null: false
  end
end
