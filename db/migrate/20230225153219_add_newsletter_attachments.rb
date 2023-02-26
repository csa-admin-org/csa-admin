class AddNewsletterAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :newsletter_attachments do |t|
      t.references :newsletter, null: false, foreign_key: true
      t.timestamps
    end
  end
end
