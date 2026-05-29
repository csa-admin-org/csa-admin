# frozen_string_literal: true

class AddIndexToNewslettersAudience < ActiveRecord::Migration[8.1]
  def change
    add_index :newsletters, :audience
  end
end
