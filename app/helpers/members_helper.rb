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

  def basket_sizes_collection(no_basket_option: true)
    col = BasketSize.all.map { |bs|
      details = []
      if bs.price.positive?
        details << "#{short_price(bs.price)} x #{deliveries_count(deliveries_counts)}"
      else
        details << deliveries_count(deliveries_counts)
      end
      details << activities_count(bs.activity_participations_demanded_annualy)
      details << acp_shares_number(bs.acp_shares_number)
      [
        collection_text(bs.name,
          price: deliveries_based_price_info(bs.price, deliveries_counts),
          details: details.compact.join(', ')),
        bs.id
      ]
    }
    if no_basket_option
      col << [
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
    col
  end

  def basket_prices_extra_collection
    [
      [0.0, 20],
      [1.0, 21],
      [2.0, 22],
      [4.0, 24],
      [8.0, 28]
    ].map { |(extra, hours)|
      details = "salaire jardinier ~#{hours}.- net/h, ~#{hours * 100}.- net/m à 50%"
      [
        if extra.zero?
          collection_text('Tarif de base', details: details)
        else
          collection_text("+ #{extra.to_i}.-/panier",
            price: deliveries_based_price_info(extra, deliveries_counts),
            details: details)
        end,
        extra
      ]
    }
  end

  def basket_complements_collection
    BasketComplement
      .visible
      .select { |bc| bc.deliveries_count.positive? }
      .map { |bc|
        if bc.annual_price_type?
          [
            collection_text(bc.name,
              price: price_info(bc.price),
              details: deliveries_count(bc.deliveries_count)),
            bc.id
          ]
        else
          d_counts = depots_delivery_ids.map { |d_ids|
            (d_ids & bc.delivery_ids).size
          }.uniq
          [
            collection_text(bc.name,
              price: deliveries_based_price_info(bc.price, d_counts),
              details: "#{short_price(bc.price)} x #{deliveries_count(d_counts)}"),
            bc.id
          ]
        end
      }
  end

  def depots_collection(membership = nil)
    visible_depots(membership).map { |d|
      details = []
      if deliveries_counts.many?
        if d.price.positive?
          details << "#{short_price(d.price)} x #{deliveries_count(d.deliveries_count)}"
        else
          details << deliveries_count(d.deliveries_count)
        end
      elsif d.price.positive?
        details << "#{short_price(d.price)}/#{Delivery.model_name.human(count: 1).downcase}"
      end
      if address = d.full_address
        details << address + map_icon(address).html_safe
      elsif d.address.present?
        details << d.address
      end
      [
        collection_text(d.form_name || d.name,
          price: price_info(d.annual_price),
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

  def diplay_address(member)
    parts = [
      member.address,
      "#{member.zip} #{member.city}",
      member.country.translations[I18n.locale.to_s]
    ].join("</br>").html_safe
  end

  def display_emails(member)
    emails = member.emails_array - [current_session.email]
    parts = [content_tag(:i, current_session.email)]
    parts += emails
    parts.join(', ').html_safe
  end

  def display_phones(member)
    member.phones_array.map(&:phony_formatted).join(', ')
  end

  private

  def visible_depots(membership = nil)
    depot_ids = Depot.visible.pluck(:id)
    depot_ids << membership.depot_id if membership
    Depot.where(id: depot_ids.uniq).order('form_priority, price, name').to_a
  end

  def deliveries_counts
    @deliveries_counts ||= visible_depots.map(&:deliveries_count).uniq.sort
  end

  def depots_delivery_ids
    @depots_delivery_ids ||= visible_depots.map(&:delivery_ids)
  end

  def short_price(price)
    precision = price_precision(price)
    precision == 0 ? "#{price.to_i}.-" : "%.#{precision}f" % price
  end

  def price_info(price, **options)
    options[:precision] ||= price_precision(price.round_to_five_cents)
    cur(price.round_to_five_cents, **options) if price.positive?
  end

  def price_precision(price)
    splitted = price.to_s.split('.')
    if splitted.many?
      decimals = splitted.last
      decimals.to_i == 0 ? 0 : [decimals.length, 2].max
    else
      0
    end
  end

  def deliveries_based_price_info(price, deliveries_counts)
    if deliveries_counts.many?
      [
        price_info(deliveries_counts.min * price),
        price_info(deliveries_counts.max * price, format: '%n')
      ].join('-')
    else
      price_info(deliveries_counts.first.to_i * price)
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
      inline_svg_pack_tag 'media/images/members/map_signs.svg', size: '16px'
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
