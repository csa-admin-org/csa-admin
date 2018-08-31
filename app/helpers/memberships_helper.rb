module MembershipsHelper
  def membership_short_period(membership)
    [:started_on, :ended_on].map { |d|
      I18n.l(membership.send(d), format: :number)
    }.join(' – ')
  end

  def basket_size_description(object, text_only: false)
    case object
    when Basket
      case object.quantity
      when 1 then object.basket_size.name
      else "#{object.quantity}x #{object.basket_size.name}"
      end
    when Membership
      desc =
        case object.basket_quantity
        when 1 then object.basket_size.name
        else "#{object.basket_quantity}x #{object.basket_size.name}"
        end
      desc += " (#{object.season_name})" unless object.all_seasons?
      desc
    else
      content_tag(:em, t('activerecord.models.basket_size.none'), class: 'empty') unless text_only
    end
  end

  def basket_complements_description(complements, text_only: false)
    names = Array(complements).compact.map do |complement|
      desc =
        case complement.quantity
        when 1 then complement.basket_complement.name
        else "#{complement.quantity} x #{complement.basket_complement.name}"
        end
      desc += " (#{complement.season_name})" unless complement.all_seasons?
      desc
    end
    if names.present?
      names.to_sentence
    elsif !text_only
      content_tag :em, t('activerecord.models.basket_complement.none'), class: 'empty'
    end
  end

  def basket_sizes_price_info(baskets)
    baskets
      .pluck(:quantity, :basket_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, baskets|
        "#{baskets.sum { |q,_| q }}x#{precise_cur(price)}"
      }.join(' + ')
  end

  def membership_basket_complements_price_info(membership)
    (
      membership.memberships_basket_complements
        .joins(:basket_complement)
        .where(basket_complements: { price_type: 'annual' })
        .order('memberships_basket_complements.price')
        .map { |mbc|
          "#{mbc.quantity}x#{precise_cur(mbc.price)}"
        } +
      membership.baskets
        .joins(baskets_basket_complements: :basket_complement)
        .where(basket_complements: { price_type: 'delivery' })
        .pluck('baskets_basket_complements.quantity', 'baskets_basket_complements.price')
        .group_by { |_, price| price }
        .sort
        .map { |price, bbcs|
          "#{bbcs.sum { |q,_| q }}x#{precise_cur(price)}"
        }
    ).join(' + ')
  end

  def basket_complement_price_info(membership, basket_complement)
    if basket_complement.annual_price_type?
      mbc = membership.memberships_basket_complements
        .where(basket_complement: basket_complement)
        .first
      "#{mbc.quantity}x#{precise_cur(mbc.price)}"
    else
      membership.baskets
        .joins(baskets_basket_complements: :basket_complement)
        .where(baskets_basket_complements: { basket_complement: basket_complement })
        .pluck('baskets_basket_complements.quantity', 'baskets_basket_complements.price')
        .group_by { |_, price| price }
        .sort
        .map { |price, bbcs|
          "#{bbcs.sum { |q,_| q }}x#{precise_cur(price)}"
        }.join(' + ')
    end
  end

  def distributions_price_info(baskets)
    baskets
      .pluck(:quantity, :distribution_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, baskets|
        "#{baskets.sum { |q,_| q }}x#{precise_cur(price)}"
      }.join(' + ')
  end

  private

  def precise_cur(number)
    precision = number.to_s.split('.').last.size > 2 ? 3 : 2
    number_to_currency(number, unit: '', precision: precision)
  end
end
