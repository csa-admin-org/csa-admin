module MembersHelper
  def link_with_session(member, session)
    link = auto_link(member)
    link += " (#{session.email})" if session&.email
    link
  end

  def languages_collection
    Current.acp.languages.map { |l| [t("languages.#{l}"), l] }
  end

  def billing_year_divisions_collection
    Current.acp.billing_year_divisions.map { |i|
      [I18n.t("billing.year_division.x#{i}"), i]
    }
  end

  def basket_sizes_collection
    BasketSize.all.map { |bs|
      [
        collection_text(bs.name,
          price: basket_size_price_info(bs.price),
          details: [
            deliveries_count(deliveries_counts),
            activities_count(bs.activity_participations_demanded_annualy),
            acp_shares_number(bs.acp_shares_number)
          ].compact.join(', ')),
        bs.id
      ]
    } << [
      collection_text(t('helpers.no_basket_size'),
        details:
          if Current.acp.annual_fee
            t('helpers.no_basket_size_annual_fee')
          elsif Current.acp.share?
            t('helpers.no_basket_size_acp_share')
          end
      ),
      0
    ]
  end

  def basket_complements_collection
    BasketComplement
      .visible
      .select { |bc| bc.deliveries_count.positive? }
      .map { |bc|
        [
          collection_text(bc.name,
            price: price_info(bc.annual_price, precision: 2),
            details: deliveries_count(bc.deliveries_count)),
          bc.id
        ]
      }
  end

  def depots_collection
    visible_depots.map { |d|
      details = []
      details << deliveries_count(d.deliveries_count) if deliveries_counts.many?
      if address = d.full_address
        details << address + map_icon(address).html_safe
      elsif d.address.present?
        details << d.address
      end
      [
        collection_text(d.form_name || d.name,
          price: price_info(d.annual_price, precision: 0),
          details: details.compact.join(', ')),
        d.id
      ]
    }
  end

  def terms_of_service_label
    if Current.acp.statutes_url
      t('.terms_of_service_with_statutes',
        terms_url: Current.acp.terms_of_service_url,
        statutes_url: Current.acp.statutes_url).html_safe
    else
      t('.terms_of_service',
        terms_url: Current.acp.terms_of_service_url).html_safe
    end
  end

  private

  def visible_depots
    @visible_depots ||= Depot.visible.reorder('form_priority, price, name').to_a
  end

  def deliveries_counts
    @deliveries_counts ||= visible_depots.map(&:deliveries_count).uniq.sort
  end

  def price_info(price, *options)
    number_to_currency(price.round_to_five_cents, *options) if price.positive?
  end

  def basket_size_price_info(price)
    if deliveries_counts.many?
      [
        price_info(deliveries_counts.min * price, precision: 0),
        price_info(deliveries_counts.max * price, precision: 0, format: '%n')
      ].join('-')
    else
      price_info(deliveries_counts.first.to_i * price, precision: 0)
    end
  end

  def collection_text(text, price: nil, details: nil)
    txts = [text]
    txts << "<em class='price'>#{price}</em>" if price
    txts << "<em>(#{details})</em>" if details.present?
    txts.join.html_safe
  end

  def map_icon(location)
    link_to "https://www.google.com/maps?q=#{location}", title: location, target: :blank, class: 'map_link' do
      inline_svg_tag 'map_signs.svg', size: '16px'
    end
  end

  def deliveries_count(counts)
    case counts
    when Array
      if counts.many?
        "#{counts.min}-#{counts.max}&nbsp;#{Delivery.model_name.human(count: counts.max)}".downcase
      else
        count = counts.first.to_i
        "#{count}&nbsp;#{Delivery.model_name.human(count: count)}".downcase
      end
    when Integer
      "#{counts}&nbsp;#{Delivery.model_name.human(count: counts)}".downcase
    end
  end

  def activities_count(count)
    return unless Current.acp.feature?('activity')

    t_activity('helpers.activities_count_per_year', count: count).gsub(/\s/, '&nbsp;')
  end

  def acp_shares_number(number)
    return unless number

    t('helpers.acp_shares_number', count: number)
  end
end
