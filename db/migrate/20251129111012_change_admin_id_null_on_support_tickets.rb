# frozen_string_literal: true

class ChangeAdminIdNullOnSupportTickets < ActiveRecord::Migration[8.1]
  def change
    change_column_null :support_tickets, :admin_id, false
  end
end
