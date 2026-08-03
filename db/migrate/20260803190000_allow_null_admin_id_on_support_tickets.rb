# frozen_string_literal: true

class AllowNullAdminIdOnSupportTickets < ActiveRecord::Migration[8.1]
  def change
    # Keep ticket history when an admin is deleted (Admin has_many :tickets, dependent: :nullify).
    change_column_null :support_tickets, :admin_id, true
  end
end
