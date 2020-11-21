class CreateMailTemplates < ActiveRecord::Migration[6.0]
  def change
    create_table :mail_templates do |t|
      t.string :title, null: false
      t.boolean :active, default: false, null: false
      t.jsonb :subjects, default: {}, null: false
      t.jsonb :contents, default: {}, null: false

      t.timestamps
    end
    add_index :mail_templates, :title, unique: true
  end
end
