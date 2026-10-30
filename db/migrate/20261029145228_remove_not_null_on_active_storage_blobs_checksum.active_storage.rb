# frozen_string_literal: true

# This migration comes from active_storage (originally 20211119233751)
class RemoveNotNullOnActiveStorageBlobsChecksum < ActiveRecord::Migration[6.0]
  def change
    return unless table_exists?(:active_storage_blobs)
    # SQLite change_column_null rebuilds the table even when null is already true.
    return if column_exists?(:active_storage_blobs, :checksum, null: true)

    change_column_null(:active_storage_blobs, :checksum, true)
  end
end
