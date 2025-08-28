# frozen_string_literal: true

class AddMembershipIdsToNewsletterSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :newsletter_segments, :membership_ids, :json, default: [], null: false

    add_check_constraint :newsletter_segments, "JSON_TYPE(membership_ids) = 'array'",
      name: "newsletter_segments_membership_ids_is_array"
  end
end
