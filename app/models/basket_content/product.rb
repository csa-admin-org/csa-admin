# frozen_string_literal: true

require "public_suffix"

class BasketContent
  class Product < ApplicationRecord
    include TranslatedAttributes

    translated_attributes :name, required: true

    has_many :basket_contents
    has_many :deliveries, through: :basket_contents

    validates :default_unit, inclusion: { in: BasketContent::UNITS }, allow_nil: true
    validates :default_unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :default_unit_and_price_presence

    with_options class_name: "BasketContent" do
      has_one :latest_basket_content, -> {
        joins(:delivery).merge(Delivery.unscoped.order(date: :desc))
      }
      has_one :latest_basket_content_in_kg, -> {
        joins(:delivery).merge(Delivery.unscoped.order(date: :desc)).in_kg
      }
      has_one :latest_basket_content_in_pc, -> {
        joins(:delivery).merge(Delivery.unscoped.order(date: :desc)).in_pc
      }
    end

    scope :ordered, -> { order_by_name }

    validates :names, uniqueness: true

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
