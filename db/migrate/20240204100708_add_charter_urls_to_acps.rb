# frozen_string_literal: true

class AddCharterUrlsToAcps < ActiveRecord::Migration[7.1]
  def change
    add_column :acps, :charter_urls, :jsonb, default: {}, null: false
  end
end
