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

  def basket_size_description(object, text_only: false, public_name: true)
    name = public_name ? object.basket_size.public_name : object.basket_size.name
    case object
    when Basket
      case object.quantity
      when 1 then name
      else "#{object.quantity}x #{name}"
      end
    when Membership
      case object.basket_quantity
      when 1 then name
      else "#{object.basket_quantity}x #{name}"
      end
    else
      content_tag(:em, t('activerecord.models.basket_size.none'), class: 'empty') unless text_only
    end
  end

  def basket_complements_description(complements, text_only: false, public_name: true)
    names = Array(complements).compact.map do |complement|
      name = public_name ? complement.basket_complement.public_name : complement.basket_complement.name
      case complement.quantity
      when 1 then name
      else "#{complement.quantity} x #{name}"
      end
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
        "#{bbs.sum { |q, _| q }}x #{precise_cur(price).strip}"
      }.join(' + ')
  end

  def show_basket_price_extras?
    Current.acp.feature?('basket_price_extra') &&
      Current.acp.basket_price_extra_public_title.present? &&
      Current.acp.basket_price_extras?
  end

  def baskets_extra_price_info(membership)
    "#{membership.baskets.billable.sum(:quantity)}x #{precise_cur(membership.basket_price_extra).strip}"
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
