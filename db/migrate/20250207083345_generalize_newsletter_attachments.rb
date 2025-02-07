# frozen_string_literal: true

class GeneralizeNewsletterAttachments < ActiveRecord::Migration[8.0]
  def change
    rename_table :newsletter_attachments, :attachments
    add_reference :attachments, :attachable, polymorphic: true, index: true
    change_column_null :attachments, :newsletter_id, true

    up_only do
      execute "UPDATE attachments SET attachable_type = 'Newsletter', attachable_id = newsletter_id"
      execute "UPDATE active_storage_attachments SET record_type = 'Attachment' WHERE record_type = 'Newsletter::Attachment'"
    end
  end
end
