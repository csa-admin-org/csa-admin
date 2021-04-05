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
    basket_sizes = BasketSize.reorder(price: :desc)
    acp_shares_numbers = basket_sizes.pluck(:acp_shares_number).uniq
    col = basket_sizes.map { |bs|
      details = []
      if bs.price.positive?
        details << "#{short_price(bs.price)} x #{deliveries_count(deliveries_counts)}"
      else
        details << deliveries_count(deliveries_counts)
      end
      details << activities_count(bs.activity_participations_demanded_annualy)
      if acp_shares_numbers.size > 1
        details << acp_shares_number(bs.acp_shares_number)
      end
      [
        collection_text(bs.name,
          price: deliveries_based_price_info(bs.price),
          details: details.compact.join(', ')),
        bs.id,
        data: { acp_shares_number: bs.acp_shares_number }
      ]
    }
    if no_basket_option && (Current.acp.annual_fee? || Current.acp.share?)
      col << [
        collection_text(t('helpers.no_basket_size'),
          details:
            if Current.acp.annual_fee
              t('helpers.no_basket_size_annual_fee')
            elsif Current.acp.share?
              t('helpers.no_basket_size_acp_share')
            end
        ),
        0,
        data: { acp_shares_number: 1 }
      ]
    end
    col
  end

  def basket_prices_extra_collection
    return unless Current.acp.basket_price_extras?

    label_template = Liquid::Template.parse(Current.acp.basket_price_extra_label)
    details_template = Liquid::Template.parse(Current.acp.basket_price_extra_label_detail)
    Current.acp[:basket_price_extras].map do |extra|
      text = collection_text(label_template.render('extra' => extra),
        price: extra.positive? ? deliveries_based_price_info(extra) : nil,
        details: details_template.render('extra' => extra))
      [text, extra]
    end
  end

  def basket_complement_label(bc)
    if bc.annual_price_type?
      collection_text(bc.name,
        price: price_info(bc.price),
        details: deliveries_count(bc.deliveries_count))
    else
      d_counts = depots_delivery_ids.map { |d_ids|
        (d_ids & bc.delivery_ids).size
      }.uniq
      collection_text(bc.name,
        price: deliveries_based_price_info(bc.price, d_counts),
        details: "#{short_price(bc.price)} x #{deliveries_count(d_counts)}")
    end
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
        details << t('helpers.price_per_delivery', price: short_price(d.price))
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
    if Current.acp.terms_of_service_url && Current.acp.statutes_url
      t('.terms_of_service_with_statutes',
        terms_url: Current.acp.terms_of_service_url,
        statutes_url: Current.acp.statutes_url).html_safe
    elsif Current.acp.terms_of_service_url
      t('.terms_of_service',
        terms_url: Current.acp.terms_of_service_url).html_safe
    elsif Current.acp.statutes_url
      t('.terms_of_service_with_only_statutes',
        statutes_url: Current.acp.statutes_url).html_safe
    end
  end

  def display_address(member, country: true)
    parts = [
      member.address,
      "#{member.zip} #{member.city}",
    ]
    parts << member.country.translations[I18n.locale.to_s] if country
    parts.join("</br>").html_safe
  end

  def display_emails(member)
    emails = member.emails_array - [current_session.email]
    parts = [content_tag(:i, current_session.email)]
    parts += emails
    parts.join(', ').html_safe
  end

  def display_phones(member)
    parts = []
    member.phones_array.each do |phone|
      parts << link_to(phone.phony_formatted, 'tel:' + phone.phony_formatted(spaces: '', format: :international))
    end
    parts.join(', ').html_safe
  end

  def display_acp_shares_number(member)
    parts = []
    if member.existing_acp_shares_number&.positive?
      parts << t('.acp_shares_number.existing', count: member.existing_acp_shares_number)
    end
    invoiced_number = member.invoices.not_canceled.acp_share.sum(:acp_shares_number)
    if invoiced_number.positive?
      parts << link_to(
        t('.acp_shares_number.invoiced', count: invoiced_number),
        invoices_path(q: { member_id_eq: member.id, object_type_in: 'ACPShare' }, scope: :all))
    end
    if member.missing_acp_shares_number.positive?
      parts << t('.acp_shares_number.missing', count: member.missing_acp_shares_number)
    end
    parts.to_sentence.html_safe
  end

  def deliveries_based_price_info(price, d_counts = deliveries_counts)
    if d_counts.many?
      [
        price_info(d_counts.min * price),
        price_info(d_counts.max * price, format: '%n')
      ].join('-')
    else
      price_info(d_counts.first.to_i * price)
    end
  end

  def deliveries_count(counts = deliveries_counts)
    case counts
    when Array
      if counts.many?
        t('helpers.deliveries_counts_range', range: "#{counts.min}-#{counts.max}")
      else
        t('helpers.deliveries_count', count: counts.first.to_i)
      end
    when Integer
      t('helpers.deliveries_count', count: counts)
    end
  end

  private

  def visible_depots(membership = nil)
    depot_ids = Depot.visible.pluck(:id)
    depot_ids << membership.depot_id if membership
    Depot.where(id: depot_ids.uniq).reorder('form_priority, price, name').to_a
  end

  def deliveries_counts
    @deliveries_counts ||= visible_depots.map(&:deliveries_count).uniq.sort
  end

  def depots_delivery_ids
    @depots_delivery_ids ||= visible_depots.map(&:delivery_ids)
  end

  def short_price(price)
    precision = price_precision(price)
    case precision
    when 0; "#{price.to_i}.-"
    when 3; "~%.2f" % price.round_to_five_cents
    else
      "%.#{precision}f" % price
    end
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

  def activities_count(count)
    return unless Current.acp.feature?('activity')

    t_activity('helpers.activities_count_per_year', count: count).gsub(/\s/, '&nbsp;')
  end

  def acp_shares_number(number)
    return unless number

    t('helpers.acp_shares_number', count: number)
  end
end
