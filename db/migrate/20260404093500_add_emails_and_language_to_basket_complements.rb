# frozen_string_literal: true

class AddEmailsAndLanguageToBasketComplements < ActiveRecord::Migration[8.0]
  def change
    add_column :basket_complements, :emails, :string
    add_column :basket_complements, :language, :string, null: false, default: "fr"
  end
end
