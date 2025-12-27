# frozen_string_literal: true

module Organization::BasketPriceExtraFeature
  extend ActiveSupport::Concern

  included do
    translated_attributes :basket_price_extra_title, :basket_price_extra_public_title, :basket_price_extra_text
    translated_attributes :basket_price_extra_label, :basket_price_extra_label_detail

    validate :basket_price_extra_dynamic_pricing_logic_must_be_valid

    def basket_price_extra_title
      self[:basket_price_extra_titles][I18n.locale.to_s].presence
        || self.class.human_attribute_name(:basket_price_extra)
    end

    def basket_price_extra_public_title
      self[:basket_price_extra_public_titles][I18n.locale.to_s].presence
        || basket_price_extra_title
    end
  end

  def basket_price_extra_label_detail_default
    "{% if extra != 0 %}{{ full_year_price }}{% endif %}"
  end

  def basket_price_extra_label_detail_or_default
    basket_price_extra_label_detail.presence || basket_price_extra_label_detail_default
  end

  def basket_price_extras?
    self[:basket_price_extras].any?
  end

  def basket_price_extras
    self[:basket_price_extras].join(", ")
  end

  def basket_price_extras=(string)
    self[:basket_price_extras] = string.split(",").map(&:presence).compact.map(&:to_f)
  end

  def calculate_basket_price_extra(extra, basket_size_price, basket_size_id, complements_price, deliveries_count)
    return extra unless basket_price_extra_dynamic_pricing?

    template = Liquid::Template.parse(basket_price_extra_dynamic_pricing)
    template.render(
      "extra" => extra.to_f,
      "basket_size_price" => basket_size_price.to_f,
      "basket_size_id" => basket_size_id,
      "complements_price" => complements_price.to_f,
      "deliveries_count" => deliveries_count.to_f
    ).to_f
  end

  private

  def basket_price_extra_dynamic_pricing_logic_must_be_valid
    Liquid::Template.parse(basket_price_extra_dynamic_pricing)
  rescue Liquid::SyntaxError => e
    errors.add(:basket_price_extra_dynamic_pricing, e.message)
  end
end
