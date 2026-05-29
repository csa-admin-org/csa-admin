# frozen_string_literal: true

class AddMemberIdsToNewsletterSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :newsletter_segments, :member_ids, :json, default: [], null: false

    add_check_constraint :newsletter_segments, "JSON_TYPE(member_ids) = 'array'",
      name: "newsletter_segments_member_ids_is_array"
  end
end
