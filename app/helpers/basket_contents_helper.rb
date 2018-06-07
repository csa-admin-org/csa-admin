module BasketContentsHelper
  def display_quantity(basket_content)
    case basket_content.unit
    when 'kilogramme' then "#{basket_content.quantity}kg"
    when 'pièce' then  "#{basket_content.quantity.to_i}p"
    end
  end

  def display_basket_quantity(basket_content, size)
    count = basket_content.send("#{size}_baskets_count")
    return '–' if count.zero?
    quantity = basket_content.send("#{size}_basket_quantity")
    case basket_content.unit
    when 'kilogramme' then "#{count}x #{(quantity * 1000).to_i}g"
    when 'pièce' then  "#{count}x #{quantity.to_i}p"
    end
  end

  def display_lost_quantity(basket_content)
    quantity = basket_content.lost_quantity
    case basket_content.unit
    when 'kilogramme' then "#{(quantity * 1000).to_i}g"
    when 'pièce' then  "#{quantity.to_i}p"
    end
  end

  def display_distributions(basket_content)
    all_distributions = Distribution.all
    distributions = basket_content.distributions
    if distributions.size == all_distributions.size
      'Tous'
    elsif all_distributions.size - distributions.size < 3
      missing = all_distributions - distributions
      "Tous, sauf #{missing.map(&:name).join(' et ')}"
    else
      distributions.map(&:name).join(', ')
    end
  end

  def small_basket
    BasketSize.reorder(:price).first
  end

  def big_basket
    BasketSize.reorder(:price).last
  end
end
