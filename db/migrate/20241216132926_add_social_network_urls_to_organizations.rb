# frozen_string_literal: true

class AddSocialNetworkUrlsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :social_network_urls, :json, default: [], null: false

    add_check_constraint :organizations, "JSON_TYPE(social_network_urls) = 'array'",
      name: "organizations_social_network_urls_is_array"
  end
end
