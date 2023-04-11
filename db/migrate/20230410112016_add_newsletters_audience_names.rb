class AddNewslettersAudienceNames < ActiveRecord::Migration[7.0]
  def change
    add_column :newsletters, :audience_names, :jsonb, default: {}, null: false
  end
end
