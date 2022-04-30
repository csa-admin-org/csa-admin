module BasketContentsHelper
  include NumbersHelper

  def display_quantity(quantity, unit)
    case unit
    when 'g'; I18n.t("units.g_quantity", quantity: number_with_delimiter(quantity))
    when 'kg'; I18n.t("units.kg_quantity", quantity: number_with_delimiter(quantity))
    when 'pc'; I18n.t("units.pc_quantity", quantity: number_with_delimiter(quantity.to_i))
    end
  end

  def display_basket_quantity(basket_content, basket_size)
    count = basket_content.baskets_count(basket_size)
    quantity = basket_content.basket_quantity(basket_size)
    return '–' if count.nil? || quantity.nil? || count.zero? || quantity.zero?

    case basket_content.unit
    when 'kg'
      I18n.t('units.g_count_quantity', count: count, quantity: number_with_delimiter((quantity * 1000).to_i))
    else
      I18n.t("units.#{basket_content.unit}_count_quantity", count: count, quantity: number_with_delimiter(quantity.to_i))
    end
  end

  def display_surplus_quantity(basket_content)
    quantity = basket_content.surplus_quantity
    case basket_content.unit
    when 'kg'; display_quantity((quantity * 1000).to_i, 'g')
    when 'pc'; display_quantity(quantity.to_i, 'pc')
    end
  end

  def display_depots(basket_content, all_depots)
    depots = basket_content.depots
    if depots.size == all_depots.size
      I18n.t('basket_content.depots.all')
    elsif all_depots.size - depots.size < 3
      missing = all_depots - depots
      I18n.t('basket_content.depots.all_but',
        missing: missing.map(&:name).to_sentence)
    else
      depots.map(&:name).to_sentence
    end
  end

  def depot_prices_list(depot_prices)
    depot_prices.sort_by { |d, p| [p, d.name] }.map do |depot, price|
      "#{depot.name}:#{cur(price, unit: false)}"
    end.join("&#xa;").html_safe
  end

  def display_basket_price_with_diff(base_price, prices)
    prices.map { |price|
      content_tag(:div, class: 'price-diff') {
        (content_tag(:span, cur(price, unit: false, format: '%n'), class: 'price') +
          display_basket_price_diff(base_price, price - base_price))
      }
    }.join(content_tag(:span, '-', class: 'main-divider')).html_safe
  end

  def display_basket_price_diff(base_price, diff)
    per = (diff / base_price * 100).round(1)
    plus_sign = diff.positive? ? '+' : ''
    color_class =
      if per.in?(-5..5)
        'neutral'
      elsif per > 5
        'positive'
      else
        'negative'
      end
    content_tag :span, class: "diff #{color_class}" do
      [
        "#{plus_sign}#{cur(diff, unit: false, format: '%n')}",
        "#{plus_sign}#{per}%"
      ].join(content_tag(:span, '/', class: 'divider')).html_safe
    end.html_safe
  end

  def display_with_price(price, quantity)
    return yield unless price.present? && quantity.present?

    (
      yield +
      content_tag(:span, cur(price * quantity), class: 'price')
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
    (yield + content_tag(:span, unit_price, class: 'price')).html_safe
  end

  def units_collection
    BasketContent::UNITS.map do |unit|
      [I18n.t("units.#{unit}"), unit]
    end
  end

  def basket_content_products_collection
    BasketContent::Product.includes(:latest_basket_content).map do |product|
      data = {}
      if basket_content = product.latest_basket_content
        data[:form_select_option_defaults] = {
          basket_content_quantity: basket_content.quantity,
          basket_content_unit_price: basket_content.unit_price,
          basket_content_unit: basket_content.unit,
        }
      end
      if product.url?
        data[:form_hint_url] = {
          text: product.url_domain,
          href: product.url
        }
      end
      [product.name, product.id, data: data]
    end
  end
end
