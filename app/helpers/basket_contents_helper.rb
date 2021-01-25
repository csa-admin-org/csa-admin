module BasketContentsHelper
  def display_quantity(quantity, unit)
    case unit
    when 'g'; I18n.t("units.g_quantity", quantity: quantity)
    when 'kg'; I18n.t("units.kg_quantity", quantity: quantity)
    when 'pc'; I18n.t("units.pc_quantity", quantity: quantity.to_i)
    end
  end

  def display_basket_quantity(basket_content, basket_size)
    count = basket_content.baskets_count(basket_size)
    quantity = basket_content.basket_quantity(basket_size)
    return '–' if count.nil? || quantity.nil? || count.zero? || quantity.zero?

    case basket_content.unit
    when 'kg'
      I18n.t('units.g_count_quantity', count: count, quantity: (quantity * 1000).to_i)
    else
      I18n.t("units.#{basket_content.unit}_count_quantity", count: count, quantity: quantity.to_i)
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

  def units_collection
    BasketContent::UNITS.map do |unit|
      [I18n.t("units.#{unit}"), unit]
    end
  end
end
