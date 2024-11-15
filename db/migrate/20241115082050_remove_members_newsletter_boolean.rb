# frozen_string_literal: true

class RemoveMembersNewsletterBoolean < ActiveRecord::Migration[8.0]
  def change
    remove_column :members, :newsletter, :boolean
  end
end
