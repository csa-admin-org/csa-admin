module BasketContentsHelper
  def display_quantity(basket_content, quantity: nil)
    quantity ||= basket_content.quantity
    t("units.#{basket_content.unit}_quantity", quantity: quantity)
  end

  def display_basket_quantity(basket_content, size, count: nil)
    count ||= basket_content.send("#{size}_baskets_count")
    quantity = basket_content.send("#{size}_basket_quantity")
    return '–' if count.zero? || quantity.zero?

    case basket_content.unit
    when 'kg'
      t('units.g_count_quantity', count: count, quantity: (quantity * 1000).to_i)
    else
      t("units.#{basket_content.unit}_count_quantity", count: count, quantity: quantity.to_i)
    end
  end

  def display_surplus_quantity(basket_content)
    quantity = basket_content.surplus_quantity
    case basket_content.unit
    when 'kg'
      t('units.g_quantity', quantity: (quantity * 1000).to_i)
    else
      t("units.#{basket_content.unit}_quantity", quantity: quantity.to_i)
    end
  end

  def display_depots(basket_content)
    all_depots = Depot.all
    depots = basket_content.depots
    if depots.size == all_depots.size
      t('basket_content.depots.all')
    elsif all_depots.size - depots.size < 3
      missing = all_depots - depots
      t('basket_content.depots.all_but',
        missing: missing.map(&:name).to_sentence)
    else
      depots.map(&:name).to_sentence
    end
  end

  def units_collection
    BasketContent::UNITS.map do |unit|
      [t("units.#{unit}"), unit]
    end
  end

  def small_basket
    BasketSize.small
  end

  def big_basket
    BasketSize.big
  end
end
