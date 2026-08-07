# frozen_string_literal: true

class CreateNewsletterPublications < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletter_publications do |t|
      t.references :newsletter, null: false, foreign_key: true, index: { unique: true }
      t.references :newsletter_template, null: false, foreign_key: true, index: true
      t.datetime :published_at, null: false
      t.datetime :withdrawn_at
      t.string :atom_id, null: false
      t.string :content_digest, null: false
      t.json :payload, null: false, default: {}
      t.timestamps
    end

    add_index :newsletter_publications, :atom_id, unique: true
    add_index :newsletter_publications, [ :newsletter_template_id, :published_at ],
      name: "index_newsletter_publications_on_template_and_published_at"
  end
end
