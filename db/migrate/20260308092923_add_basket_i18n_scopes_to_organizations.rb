# frozen_string_literal: true

class AddBasketI18nScopesToOrganizations < ActiveRecord::Migration[8.0]
  def change
    default = {
      "fr" => "basket",
      "de" => "share",
      "it" => "basket",
      "nl" => "package",
      "en" => "basket"
    }
    add_column :organizations, :basket_i18n_scopes, :json, default: default, null: false

    up_only do
      execute <<~SQL
        UPDATE organizations
        SET basket_i18n_scopes = json_set(basket_i18n_scopes, '$.de', 'bag')
        WHERE country_code = 'CH'
      SQL
    end
  end
end
