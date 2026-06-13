# frozen_string_literal: true

class EnableWaitingListFeatureForExistingOrganizations < ActiveRecord::Migration[8.0]
  def change
    up_only do
      execute <<~SQL
        UPDATE organizations
        SET features = json_insert(features, '$[#]', 'waiting_list')
        WHERE NOT EXISTS (
          SELECT 1
          FROM json_each(organizations.features)
          WHERE value = 'waiting_list'
        )
      SQL
    end
  end
end
