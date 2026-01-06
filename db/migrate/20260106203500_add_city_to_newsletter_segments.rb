# frozen_string_literal: true

class AddCityToNewsletterSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :newsletter_segments, :city, :string
  end
end
