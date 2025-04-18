# frozen_string_literal: true

class DepotGroup < ApplicationRecord
  include TranslatedAttributes
  include TranslatedRichTexts
  include HasPublicName

  translated_rich_texts :information_text

  has_many :depots, -> { kept }, inverse_of: :group

  scope :member_ordered, -> {
    order_clauses = [ "member_order_priority" ]
    order_clauses << "COALESCE(NULLIF(json_extract(public_names, '$.#{I18n.locale}'), ''), name)"
    reorder(Arel.sql(order_clauses.compact.join(", ")))
  }
end
