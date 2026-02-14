# frozen_string_literal: true

class CreateSearchEntries < ActiveRecord::Migration[8.1]
  def change
    create_virtual_table :search_entries, :fts5, [
      "searchable_type UNINDEXED",
      "searchable_id UNINDEXED",
      "content_primary",
      "content_secondary",
      "priority UNINDEXED",
      "updated_at UNINDEXED",
      "tokenize='trigram'"
    ]
  end
end
