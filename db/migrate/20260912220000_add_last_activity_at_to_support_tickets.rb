# frozen_string_literal: true

class AddLastActivityAtToSupportTickets < ActiveRecord::Migration[8.1]
  def up
    add_column :support_tickets, :token, :string
    add_index :support_tickets, :token, unique: true
    add_column :support_tickets, :replied_at, :datetime
    add_column :support_tickets, :last_activity_at, :datetime

    create_table :support_messages do |t|
      t.references :ticket, null: false, foreign_key: { to_table: :support_tickets }
      t.string :author, null: false
      t.references :admin, foreign_key: true
      t.string :admin_name
      t.text :body, null: false
      t.string :rfc_message_id
      t.timestamps
    end
    add_index :support_messages, :rfc_message_id, unique: true,
      where: "rfc_message_id IS NOT NULL",
      name: "idx_support_messages_on_rfc_message_id"
    add_check_constraint :support_messages,
      "author IN ('admin', 'support')",
      name: "chk_support_messages_author"

    select_all(<<~SQL).each do |row|
      SELECT support_tickets.id, support_tickets.admin_id, admins.name AS admin_name,
             support_tickets.content, support_tickets.created_at
      FROM support_tickets
      LEFT JOIN admins ON admins.id = support_tickets.admin_id
      WHERE support_tickets.token IS NULL
    SQL
      token = loop do
        candidate = SecureRandom.hex(4)
        break candidate unless select_value("SELECT 1 FROM support_tickets WHERE token = #{quote(candidate)}")
      end
      execute <<~SQL.squish
        UPDATE support_tickets
        SET token = #{quote(token)},
            last_activity_at = #{quote(row["created_at"])}
        WHERE id = #{row["id"]}
      SQL

      execute <<~SQL
        INSERT INTO support_messages (ticket_id, author, admin_id, admin_name, body, created_at, updated_at)
        VALUES (
          #{row["id"]},
          'admin',
          #{row["admin_id"] || "NULL"},
          #{row["admin_name"] ? quote(row["admin_name"]) : "NULL"},
          #{quote(row["content"])},
          #{quote(row["created_at"])},
          #{quote(row["created_at"])}
        )
      SQL
      message_id = select_value("SELECT id FROM support_messages WHERE ticket_id = #{row["id"]} ORDER BY id ASC LIMIT 1")
      execute <<~SQL
        UPDATE attachments
        SET attachable_type = 'Support::Message', attachable_id = #{message_id}
        WHERE attachable_type = 'Support::Ticket' AND attachable_id = #{row["id"]}
      SQL
    end

    change_column_null :support_tickets, :token, false
    change_column_null :support_tickets, :last_activity_at, false
    add_index :support_tickets, :last_activity_at
  end

  def down
    drop_table :support_messages
    remove_index :support_tickets, :last_activity_at
    remove_index :support_tickets, :token
    remove_column :support_tickets, :last_activity_at
    remove_column :support_tickets, :token
    remove_column :support_tickets, :replied_at
  end
end
