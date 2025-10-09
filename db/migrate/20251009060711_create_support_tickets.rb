# frozen_string_literal: true

class CreateSupportTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :support_tickets do |t|
      t.string :subject, null: false
      t.text :content, null: false
      t.text :context
      t.integer :priority, null: false
      t.references :admin, foreign_key: true

      t.timestamps
    end
  end
end
