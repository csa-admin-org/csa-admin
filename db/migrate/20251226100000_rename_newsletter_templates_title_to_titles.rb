# frozen_string_literal: true

class RenameNewsletterTemplatesTitleToTitles < ActiveRecord::Migration[8.0]
  def up
    add_column :newsletter_templates, :titles, :json, default: {}, null: false

    execute <<~SQL
      UPDATE newsletter_templates
      SET titles = json_object('en', title, 'fr', title, 'de', title, 'it', title, 'nl', title)
    SQL

    remove_index :newsletter_templates, :title
    remove_column :newsletter_templates, :title
  end

  def down
    add_column :newsletter_templates, :title, :string

    execute <<~SQL
      UPDATE newsletter_templates
      SET title = json_extract(titles, '$.en')
    SQL

    change_column_null :newsletter_templates, :title, false
    add_index :newsletter_templates, :title, unique: true

    remove_column :newsletter_templates, :titles
  end
end
