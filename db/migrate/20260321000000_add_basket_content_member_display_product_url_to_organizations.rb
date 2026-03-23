# frozen_string_literal: true

class AddBasketContentMemberDisplayProductUrlToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :basket_content_member_display_product_url, :boolean, default: false, null: false
  end
end
