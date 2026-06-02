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

  def display_total_quantity(basket_content)
    quantity = basket_content.total_quantity
    unit = basket_content.unit
    case unit
    when "kg"
      if quantity < 1
        unit = "g"
        quantity = (quantity * 1000).to_i
      end
    when "pc"
      quantity = quantity.to_i
    end

    content_tag(:span, class: "inline-flex items-baseline gap-1 ml-3 -me-3.5") {
      concat content_tag(:span, quantity, class: "tabular-nums")
      concat content_tag(:span, I18n.t("units.#{unit}.short"), class: "text-left w-2.5 text-xs text-gray-500")
    }
  end

  def display_basket_quantity(basket_content, basket_size)
    count = basket_content.baskets_count(basket_size)
    quantity = basket_content.basket_quantity(basket_size)
    return "–" if count.nil? || quantity.nil? || quantity.zero?

    content_tag(:span, class: "inline-flex items-baseline gap-1.5") do
      concat content_tag(:span, "#{count}x", class: "text-xs text-gray-500")
      concat content_tag(:span, display_quantity(quantity, basket_content.unit), class: "tabular-nums")
    end
  end

  def display_basket_quantity_editable(basket_content, basket_size)
    count = basket_content.baskets_count(basket_size)

    input_value = basket_content.basket_size_ids_quantity(basket_size)
    suffix = basket_content_unit_suffix(basket_content.unit)

    content_tag(:span,
      data: {
        controller: "inline-edit"
      },
      class: "inline-flex items-baseline gap-1.5"
    ) do
      concat content_tag(:span, class: "inline-flex items-baseline gap-1 ml-4 -me-5") {
        concat content_tag(:span, "#{count}x", class: "text-xs text-gray-500")
        concat form_tag(
          inline_update_basket_content_path(basket_content),
          method: :patch,
          class: "inline-flex items-baseline gap-0",
          data: { "inline-edit-target" => "form" }
        ) {
          hidden_field_tag(:basket_size_id, basket_size.id) +
          number_field_tag(:quantity, input_value.zero? ? nil : input_value,
            min: 0,
            step: 1,
            placeholder: "0",
            class: [ "text-input w-13 h-6 text-right tabular-nums m-0 py-0 px-1 border-0.5 border-gray-200 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none" ],
            data: {
              "inline-edit-target" => "input",
              action: "blur->inline-edit#submit keydown->inline-edit#keydown"
            }
          )
        }
        concat content_tag(:span, suffix, class: "text-left w-2.5 text-xs text-gray-500")
      }
    end
  end

  def display_depots(depots)
    depots = depots.kept
    all_depots = Depot.kept.to_a
    if depots.size == all_depots.size
      I18n.t("basket_content.depots.all")
    elsif depots.size == 1
      depots.first.name
    elsif all_depots.size - depots.size == 1
      I18n.t("basket_content.depots.all_but", missing: (all_depots - depots).first.name)
    elsif (result = display_depots_by_group(depots, all_depots))
      result
    elsif all_depots.size - depots.size < 3
      missing = all_depots - depots
      I18n.t("basket_content.depots.all_but",
        missing: missing.map(&:name).to_sentence)
    else
      depots.map(&:name).to_sentence
    end
  end

  def display_depots_by_group(depots, all_depots)
    groups = DepotGroup.includes(:depots).to_a
    return if groups.empty?

    depot_ids = depots.map(&:id).to_set
    all_depot_ids = all_depots.map(&:id).to_set

    selected_groups = groups.select { |g| g.depots.any? && g.depots.all? { |d| depot_ids.include?(d.id) } }
    excluded_groups = groups.select { |g| g.depots.any? && g.depots.none? { |d| depot_ids.include?(d.id) } }

    # "All except [group(s)]" — excluded groups fully account for missing depots
    if excluded_groups.any?
      excluded_depot_ids = excluded_groups.flat_map { |g| g.depots.map(&:id) }.to_set
      missing_depot_ids = all_depot_ids - depot_ids
      if excluded_depot_ids == missing_depot_ids
        return I18n.t("basket_content.depots.all_but",
          missing: excluded_groups.map(&:name).to_sentence)
      end
    end

    # "Only [group(s)]" — selected groups exactly account for all selected depots
    if selected_groups.any?
      selected_group_depot_ids = selected_groups.flat_map { |g| g.depots.map(&:id) }.to_set
      if selected_group_depot_ids == depot_ids
        return I18n.t("basket_content.depots.only",
          selected: selected_groups.map(&:name).to_sentence)
      end
    end

    nil
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

  def basket_price_diff_color(base_price, diff)
    per = (diff / base_price * 100).round(1)
    if per.in?(-5..5)
      :neutral
    elsif per > 5
      :green
    else
      :red
    end
  end

  def basket_price_diff_color_class(base_price, diff)
    case basket_price_diff_color(base_price, diff)
    when :neutral
      "bg-neutral-200 text-neutral-800 dark:bg-neutral-700 dark:text-neutral-200"
    when :green
      "bg-green-200 text-green-800 dark:bg-green-700 dark:text-green-200"
    when :red
      "bg-red-200 text-red-800 dark:bg-red-700 dark:text-red-200"
    end
  end

  def display_basket_price_diff(base_price, diff)
    per = (diff / base_price * 100).round(1)
    plus_sign = diff.positive? ? "+" : ""
    content_tag :span, class: "py-0.5 px-1 text-xs rounded-full #{basket_price_diff_color_class(base_price, diff)}" do
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

    (yield + content_tag(:span, class: "flex items-baseline m-0 gap-0.5 text-gray-500 whitespace-nowrap") {
      concat content_tag(:span, cur(price), class: "text-sm tabular-nums")
      concat content_tag(:span, "/#{I18n.t("units.#{unit}.short")}", class: "text-xs")
    }).html_safe
  end

  def units_collection(format: :long)
    BasketContent::UNITS.map do |unit|
      [ I18n.t("units.#{unit}.#{format}"), unit ]
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
    products = BasketContent::Product.includes(:sibling).ordered
    products.map do |product|
      data = {}

      if product.url?
        data[:form_hint_url] = {
          text: product.url_domain,
          href: product.url
        }
      end
      [ product.name_with_unit, product.id, data: data ]
    end
  end
end
