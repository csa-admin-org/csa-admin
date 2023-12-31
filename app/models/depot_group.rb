class DepotGroup < ApplicationRecord
  include TranslatedAttributes
  include TranslatedRichTexts

  translated_attributes :name, :public_name
  translated_rich_texts :information_text

  has_many :depots, inverse_of: :group

  default_scope { order_by_name }

  scope :member_ordered, -> {
    order_clauses = ['member_order_priority']
    order_clauses << "COALESCE(NULLIF(public_names->>'#{I18n.locale}', ''), name)"
    reorder(Arel.sql(order_clauses.compact.join(', ')))
  }

  def display_name; name end

  def public_name
    self[:public_names][I18n.locale.to_s].presence || name
  end
end
