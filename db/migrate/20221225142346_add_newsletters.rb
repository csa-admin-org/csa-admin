class AddNewsletters < ActiveRecord::Migration[7.0]
  def change
    create_table :newsletter_templates do |t|
      t.string :title, null: false

      t.jsonb :contents, default: {}, null: false

      t.timestamps
    end
    add_index :newsletter_templates, :title, unique: true

    create_table :newsletters do |t|
      t.references :newsletter_template, null: false, foreign_key: true, index: true
      t.jsonb :template_contents, default: {}, null: false

      t.jsonb :subjects, default: {}, null: false

      t.datetime :sent_at

      t.timestamps
    end

    create_table :newsletter_blocks do |t|
      t.references :newsletter, null: false, foreign_key: true, index: true
      t.string :block_id, null: false
      t.timestamps
    end
    add_index :newsletter_blocks, [:newsletter_id, :block_id], unique: true
  end
end
