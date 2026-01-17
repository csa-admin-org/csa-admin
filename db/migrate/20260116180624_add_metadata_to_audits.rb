# frozen_string_literal: true

class AddMetadataToAudits < ActiveRecord::Migration[8.1]
  def change
    add_column :audits, :metadata, :json, default: {}, null: false
  end
end
