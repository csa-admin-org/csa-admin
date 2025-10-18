# frozen_string_literal: true

class AddEmailsToSupportTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :support_tickets, :emails, :string
  end
end
