# frozen_string_literal: true

class ShareProducers < ActiveRecord::Migration[8.1]
  def change
    rename_table :shop_producers, :producers
    add_reference :basket_content_products, :producer, foreign_key: true

    up_only do
      execute <<~SQL.squish
        UPDATE action_text_rich_texts
        SET record_type = 'Producer'
        WHERE record_type = 'Shop::Producer'
      SQL
      execute <<~SQL.squish
        UPDATE active_storage_attachments
        SET record_type = 'Producer'
        WHERE record_type = 'Shop::Producer'
      SQL
    end
  end
end
