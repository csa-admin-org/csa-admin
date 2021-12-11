module MembershipsHelper
  def basket_description(basket, text_only: false)
    parts = [basket_size_description(basket, text_only: text_only)]
    if basket.baskets_basket_complements.any?
      parts << basket_complements_description(basket.baskets_basket_complements, text_only: text_only)
    end
    parts.join(', ')
  end

  def membership_short_period(membership)
    %i[started_on ended_on].map { |d|
      I18n.l(membership.send(d), format: :number)
    }.join(' – ')
  end

  def basket_size_description(object, text_only: false)
    case object
    when Basket
      case object.quantity
      when 1 then object.basket_size.public_name
      else "#{object.quantity}x #{object.basket_size.public_name}"
      end
    when Membership
      desc =
        case object.basket_quantity
        when 1 then object.basket_size.public_name
        else "#{object.basket_quantity}x #{object.basket_size.public_name}"
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
      if complement.respond_to?(:seasons)
        desc += " (#{complement.season_name})" unless complement.all_seasons?
      end
      desc
    end
    if names.present?
      names.to_sentence
    elsif !text_only
      content_tag :em, t('activerecord.models.basket_complement.none'), class: 'empty'
    end
  end

  def basket_sizes_price_info(membership, baskets)
    baskets
      .billable
      .pluck(:quantity, :basket_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, bbs|
        txt = "#{bbs.sum { |q, _| q }}x"
        if membership.basket_price_extra.positive?
          txt +=" (#{precise_cur(price).strip}+#{precise_cur(membership.basket_price_extra).strip})"
        else
          txt += precise_cur(price)
        end
        txt
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
        .billable
        .joins(baskets_basket_complements: :basket_complement)
        .where(basket_complements: { price_type: 'delivery' })
        .pluck('baskets_basket_complements.quantity', 'baskets_basket_complements.price')
        .group_by { |_, price| price }
        .sort
        .map { |price, bbcs|
          "#{bbcs.sum { |q, _| q }}x#{precise_cur(price)}"
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
        .billable
        .joins(baskets_basket_complements: :basket_complement)
        .where(baskets_basket_complements: { basket_complement: basket_complement })
        .pluck('baskets_basket_complements.quantity', 'baskets_basket_complements.price')
        .group_by { |_, price| price }
        .sort
        .map { |price, bbcs|
          "#{bbcs.sum { |q, _| q }}x#{precise_cur(price)}"
        }.join(' + ')
    end
  end

  def depots_price_info(baskets)
    baskets
      .billable
      .pluck(:quantity, :depot_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, bbs|
        "#{bbs.sum { |q, _| q }}x#{precise_cur(price)}"
      }.join(' + ')
  end

  def renewal_decisions_collection
    %i[renew cancel].map { |d| [t(".renewal.options.#{d}"), d] }
  end

  private

  def precise_cur(number)
    precision = number.to_s.split('.').last.size > 2 ? 3 : 2
    cur(number, unit: false, precision: precision)
  end
end
