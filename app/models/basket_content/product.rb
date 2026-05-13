# frozen_string_literal: true

require "public_suffix"

class BasketContent
  class Product < ApplicationRecord
    include TranslatedAttributes

    translated_attributes :name, required: true

    has_many :basket_contents
    has_many :deliveries, through: :basket_contents

    has_one :latest_basket_content, -> {
      joins(:delivery).merge(Delivery.unscoped.order(date: :desc))
    }, class_name: "BasketContent"

    validates :default_unit, inclusion: { in: BasketContent::UNITS, allow_blank: true }
    validates :url, format: { with: %r{\Ahttps?://.*\z}, allow_blank: true }
    validates :default_unit_price, numericality: { greater_than_or_equal_to: 0, allow_blank: true }
    validate :default_unit_and_price_presence

    scope :ordered, -> { order_by_name }

    validates :names, uniqueness: true

    def sync_latest_basket_content!
      latest = basket_contents.joins(:delivery)
        .merge(Delivery.unscoped.order(date: :desc)).first
      if latest
        update_columns(
          default_unit: latest.unit,
          default_unit_price: latest.unit_price,
          default_basket_quantities: latest.basket_size_ids_quantities
            .transform_keys(&:to_s))
      end
    end

    def url_domain
      return unless url?

      uri = URI.parse(url)
      PublicSuffix.parse(uri.host).to_s
    end

    def can_destroy?
      basket_contents.none?
    end

    private

    def default_unit_and_price_presence
      if default_unit.present? && default_unit_price.blank?
        errors.add(:default_unit_price, :blank)
      elsif default_unit.blank? && default_unit_price.present?
        errors.add(:default_unit, :blank)
      end
    end
  end
end
