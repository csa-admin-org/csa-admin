# frozen_string_literal: true

class AddMailableIdToMailDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_deliveries, :mailable_id, :integer,
      as: "CAST(json_extract(mailable_ids, '$[0]') AS INTEGER)"
    add_index :mail_deliveries, [ :mailable_type, :mailable_id ],
      name: "idx_mail_deliveries_on_mailable_type_id"
  end
end
