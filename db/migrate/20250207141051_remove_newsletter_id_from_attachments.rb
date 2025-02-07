# frozen_string_literal: true

class RemoveNewsletterIdFromAttachments < ActiveRecord::Migration[8.0]
  def change
    remove_column :attachments, :newsletter_id, :bigint
    change_column_null :attachments, :attachable_id, false
    change_column_null :attachments, :attachable_type, false
  end
end
