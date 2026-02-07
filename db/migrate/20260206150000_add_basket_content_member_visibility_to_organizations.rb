# frozen_string_literal: true

class AddBasketContentMemberVisibilityToOrganizations < ActiveRecord::Migration[8.0]
  def up
    add_column :organizations, :basket_content_member_display_quantity, :boolean, default: true, null: false
    add_column :organizations, :basket_content_member_notes, :json, default: {}, null: false
    add_column :organizations, :basket_content_member_titles, :json, default: {}, null: false
    add_column :organizations, :basket_content_member_visible, :boolean, default: false, null: false
    add_column :organizations, :basket_content_member_visible_hours_before, :integer, default: 12, null: false

    org = Organization.new
    execute ActiveRecord::Base.sanitize_sql_array([
      "UPDATE organizations SET basket_content_member_titles = ?, basket_content_member_notes = ?",
      org.default_basket_content_member_titles.to_json,
      org.default_basket_content_member_notes.to_json
    ])
  end

  def down
    remove_column :organizations, :basket_content_member_display_quantity
    remove_column :organizations, :basket_content_member_notes
    remove_column :organizations, :basket_content_member_titles
    remove_column :organizations, :basket_content_member_visible
    remove_column :organizations, :basket_content_member_visible_hours_before
  end
end
