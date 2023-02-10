class AddNewsletterDeliveries < ActiveRecord::Migration[7.0]
  def change
    create_table :newsletter_deliveries do |t|
      t.references :newsletter, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.string :emails, array: true, default: [], null: false
      t.string :suppressed_emails, array: true, default: [], null: false
      t.string :subject
      t.text :content
      t.datetime :delivered_at
      t.timestamps
    end
  end
end
