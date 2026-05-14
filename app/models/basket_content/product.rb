# frozen_string_literal: true

require "public_suffix"

class BasketContent
  class Product < ApplicationRecord
    include TranslatedAttributes

    translated_attributes :name, required: true

    has_many :basket_contents
    has_many :deliveries, through: :basket_contents

    has_one :latest_basket_content, ->(product) {
      joins(:delivery).where(unit: product.unit).merge(Delivery.unscoped.order(date: :desc))
    }, class_name: "BasketContent"

    has_one :sibling, ->(product) { where.not(unit: product.unit) },
      class_name: "BasketContent::Product",
      primary_key: :names,
      foreign_key: :names

    validates :unit, presence: true, inclusion: { in: BasketContent::UNITS }
    validates :url, format: { with: %r{\Ahttps?://.*\z}, allow_blank: true }
    validates :default_price, numericality: { greater_than_or_equal_to: 0, allow_blank: true }

    scope :ordered, -> { order_by_name }

    validates :unit, uniqueness: { scope: :names }

    def name_with_unit
      if sibling
        "#{name} (#{I18n.t("units.#{unit}.short")})"
      else
        name
      end
    end

    def sync_latest_basket_content!
      if latest = reload_latest_basket_content
        update_columns(
          default_price: latest.unit_price,
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
  end
end
