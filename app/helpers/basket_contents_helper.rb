# frozen_string_literal: true

module BasketContentsHelper
  include ActionView::Helpers::NumberHelper
  include NumbersHelper

  def smart_basket_contents_path
    @delivery ||= Delivery.next || BasketContent.closest_delivery || Delivery.last
    if @delivery
      basket_contents_path(q: { delivery_id_eq: @delivery&.id, during_year: @delivery&.fy_year })
    else
      basket_contents_path
    end
  end

  def display_quantity(quantity, unit)
    if unit == "kg" && quantity < 1
      unit = "g"
      quantity = (quantity * 1000).to_i
    end

    case unit
    when "g"; I18n.t("units.g_quantity", quantity: number_with_delimiter(quantity))
    when "kg"; I18n.t("units.kg_quantity", quantity: number_with_delimiter(quantity))
    when "pc"; I18n.t("units.pc_quantity", quantity: number_with_delimiter(quantity.to_i))
    end
  end

  def display_basket_quantity(basket_content, basket_size)
    count = basket_content.baskets_count(basket_size)
    quantity = basket_content.basket_quantity(basket_size)
    return "–" if count.nil? || quantity.nil? || count.zero? || quantity.zero?

    case basket_content.unit
    when "kg"
      I18n.t("units.g_count_quantity", count: count, quantity: number_with_delimiter((quantity * 1000).to_i))
    else
      I18n.t("units.#{basket_content.unit}_count_quantity", count: count, quantity: number_with_delimiter(quantity.to_i))
    end
  end

  def display_depots(depots)
    depots = depots.kept
    all_depots = Depot.kept.to_a
    if depots.size == all_depots.size
      I18n.t("basket_content.depots.all")
    elsif all_depots.size - depots.size < 3
      missing = all_depots - depots
      I18n.t("basket_content.depots.all_but",
        missing: missing.map(&:name).to_sentence)
    else
      depots.map(&:name).to_sentence
    end
  end

  def depot_prices_list(depot_prices)
    depot_prices.sort_by { |d, p| [ p, d.name ] }.map do |depot, price|
      "#{depot.name}:#{cur(price, unit: false)}"
    end.join("&#xa;").html_safe
  end

  def display_basket_price_with_diff(base_price, prices)
    prices.map { |price|
      content_tag(:div, class: "mt-1") {
        (content_tag(:h4, cur(price, unit: false, format: "%n"), class: "text-2xl font-bold") +
          display_basket_price_diff(base_price, price - base_price))
      }
    }.join(content_tag(:span, "–", class: "text-2xl mx-2")).html_safe
  end

  def display_basket_price_diff(base_price, diff)
    per = (diff / base_price * 100).round(1)
    plus_sign = diff.positive? ? "+" : ""
    color_class =
      if per.in?(-5..5)
        "bg-neutral-200 text-neutral-800 dark:bg-neutral-700 dark:text-neutral-200"
      elsif per > 5
        "bg-green-200 text-green-800 dark:bg-green-700 dark:text-green-200"
      else
        "bg-red-200 text-red-800 dark:bg-red-700 dark:text-red-200"
      end
    content_tag :span, class: "py-0.5 px-1 text-xs rounded-full #{color_class}" do
      [
        "#{plus_sign}#{cur(diff, unit: false, format: '%n')}",
        "#{plus_sign}#{per}%"
      ].join(content_tag(:span, "/", class: "px-1 font-extralight").html_safe).html_safe
    end.html_safe
  end

  def display_with_price(price, quantity)
    return yield unless price.present?

    (
      yield +
      content_tag(:span, cur(price * quantity.to_f), class: "block text-sm text-gray-500 whitespace-nowrap")
    ).html_safe
  end

  def display_price(price, quantity)
    if price.present? && quantity.present?
      cur(price * quantity)
    end
  end

  def display_with_unit_price(price, unit)
    return yield unless price.present?

    unit_price = I18n.t("units.#{unit}_quantity", quantity: "#{cur(price)}/")
    (yield + content_tag(:span, unit_price, class: "block text-sm text-gray-500 whitespace-nowrap")).html_safe
  end

  def units_collection
    BasketContent::UNITS.map do |unit|
      [ I18n.t("units.#{unit}"), unit ]
    end
  end

  def basket_content_unit_suffix(unit)
    unit == "pc" ? I18n.t("units.pc_quantity", quantity: "").strip : "g"
  end

  def basket_content_total_unit_suffix(unit)
    unit == "pc" ? basket_content_unit_suffix(unit) : "kg"
  end

  def basket_content_form_percentages(basket_content)
    if basket_content.basket_size_ids.any?
      basket_content.basket_size_ids_percentages
    else
      basket_content.basket_size_ids_percentages_pro_rated
    end
  end

  def basket_content_products_collection
    products = BasketContent::Product.ordered
    products.map do |product|
      data = {}

      if product.default_unit.present?
        data[:latest_basket_content_unit] = product.default_unit
        data[:latest_basket_content_unit_price] = product.default_unit_price
        data[:latest_basket_content_quantities] = product.default_basket_quantities.to_json
      end

      if product.url?
        data[:form_hint_url] = {
          text: product.url_domain,
          href: product.url
        }
      end
      [ product.name, product.id, data: data ]
    end
  end
end
