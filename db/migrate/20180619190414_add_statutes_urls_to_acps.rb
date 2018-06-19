class AddStatutesUrlsToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :statutes_urls, :jsonb, default: {}, null: false
  end
end
