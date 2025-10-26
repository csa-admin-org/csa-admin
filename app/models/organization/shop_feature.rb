# frozen_string_literal: true

module Organization::ShopFeature
  extend ActiveSupport::Concern

  included do
    attribute :shop_delivery_open_last_day_end_time, :time_only

    translated_attributes :shop_invoice_info
    translated_rich_texts :shop_text
    translated_attributes :shop_delivery_pdf_footer
    translated_attributes :shop_terms_of_sale_url

    validates :shop_order_maximum_weight_in_kg,
      numericality: { greater_than_or_equal_to: 1, allow_nil: true }
    validates :shop_order_minimal_amount,
      numericality: { greater_than_or_equal_to: 1, allow_nil: true }
    validates :shop_order_automatic_invoicing_delay_in_days,
      numericality: { only_integer: true, allow_nil: true }
  end

  def shop_member_percentages?
    self[:shop_member_percentages].any?
  end

  def shop_member_percentages
    self[:shop_member_percentages].join(", ")
  end

  def shop_member_percentages=(string)
    self[:shop_member_percentages] =
      string
        .split(",")
        .map(&:presence)
        .compact
        .map(&:to_i)
        .reject(&:zero?)
        .sort
  end
end
