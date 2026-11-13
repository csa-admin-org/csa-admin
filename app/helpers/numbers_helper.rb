# frozen_string_literal: true

module NumbersHelper
  include ActiveSupport::NumberHelper

  NBSP = "\u00A0"

  def currency_symbol(currency_code = nil)
    currency_code ||= Current.org.currency_code
    case currency_code
    when "EUR"; "€"
    else
      currency_code
    end
  end

  def ccur(object, attr, **options)
    cur(object.public_send(attr), currency_code: object.currency_code, **options)
  end

  def cur(amount, unit: true, currency_code: nil, **options)
    amount ||= 0
    options[:unit] = unit ? currency_symbol(currency_code) : ""
    options[:format] ||=
      if unit
        "%u#{NBSP}%n"
      else
        "%n"
      end
    options[:negative_format] ||=
      if unit
        "%u#{NBSP}-%n"
      else
        "-%n"
      end
    number_to_currency(amount, **options)
  end

  def kg(amount)
    number = number_to_rounded(amount,
      precision: 2,
      strip_insignificant_zeros: true)
    "#{sprintf("%.1f", number)}#{NBSP}kg"
  end

  # Shop quantities and piece weights. Up to 3 decimals, zeros stripped.
  # Round first so a SQLite SUM float does not print as 1.2500000000000002.
  def shop_quantity(number)
    return if number.nil?

    rounded = number.to_d.round(3)
    text = rounded.to_s("F")
    text.sub(/\.0+\z/, "").sub(/(\.[0-9]*?)0+\z/, "\\1")
  end

  def shop_weight(amount)
    I18n.t("units.kg_quantity", quantity: shop_quantity(amount))
  end

  def shop_unit_price(amount, variant)
    "#{cur(amount)}/#{I18n.t("units.#{variant.unit}.short")}"
  end

  def shop_catalog_price(variant)
    content_tag(:span, class: "shop-catalog-price") do
      safe_join([
        content_tag(:span, cur(variant.price), class: "shop-catalog-price-amount"),
        content_tag(:span, "/#{I18n.t("units.#{variant.unit}.short")}", class: "shop-catalog-price-unit")
      ])
    end
  end

  def shop_quantity_with_unit(quantity, variant)
    variant.kg? ? shop_weight(quantity) : shop_quantity(quantity)
  end

  def _number_to_percentage(number, **options)
    txt = number_to_percentage(number, **options)
    if number.positive?
      "+#{txt}"
    else
      txt
    end
  end

  def prefer_integer(number)
    return unless number
    return if number&.zero?

    number == number.to_i ? number.to_i : number
  end
end
