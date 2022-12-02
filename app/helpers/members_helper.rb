module MembersHelper
  def link_with_session(member, session)
    link = auto_link(member)
    link += " (#{session.email})" if session&.email
    link
  end

  def languages_collection
    Current.acp.languages.map { |l| [t("languages.#{l}"), l] }
  end

  def billing_year_divisions_collection(data: {})
    Current.acp.billing_year_divisions.map { |i|
      [
        I18n.t("billing.year_division.x#{i}"),
        i,
        data: data
      ]
    }
  end

  def basket_size_details(bs, force_default: false)
    return bs.form_details if !force_default && bs.form_details?

    @acp_shares_numbers ||= BasketSize.visible.pluck(:acp_shares_number).uniq
    details = []
    if bs.price.positive?
      details << "#{deliveries_based_price_info(bs.price)} (#{short_price(bs.price)} x #{deliveries_count(deliveries_counts)})"
    else
      details << deliveries_count(deliveries_counts)
    end
    details << activities_count(bs.activity_participations_demanded_annualy)
    if @acp_shares_numbers.size > 1
      details << acp_shares_number(bs.acp_shares_number)
    end
    details.compact.join(', ').html_safe
  end

  def basket_sizes_collection(no_basket_option: true, data: {}, no_basket_data: {})
    basket_sizes = BasketSize.visible.reorder(:form_priority, price: :desc)
    col = basket_sizes.map { |bs|
      [
        collection_text(bs.public_name, details: basket_size_details(bs)),
        bs.id,
        data: {
          form_min_value_enforcer_min_value_param: bs.acp_shares_number
        }.merge(data)
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
        data: {
          form_min_value_enforcer_min_value_param: 1
        }.merge(no_basket_data)
      ]
    end
    col
  end

  def basket_prices_extra_collection(data: {})
    return unless Current.acp.basket_price_extras?

    label_template = Liquid::Template.parse(Current.acp.basket_price_extra_label)
    details_template = Liquid::Template.parse(Current.acp.basket_price_extra_label_detail_or_default)
    Current.acp[:basket_price_extras].map do |extra|
      full_year_price = deliveries_based_price_info(extra) unless extra.zero?
      details = details_template.render(
        'extra' => extra,
        'full_year_price' => full_year_price)

      text = collection_text(label_template.render('extra' => extra), details: details)
      [text, extra, data: data]
    end
  end

  def basket_complement_details(bc, force_default: false)
    return bc.form_details if !force_default && bc.form_details?

    if bc.annual_price_type?
      "#{price_info(bc.price)} (#{deliveries_count(bc.deliveries_count)})".html_safe
    else
      d_counts = depots_delivery_ids.map { |d_ids|
        (d_ids & bc.delivery_ids).size
      }.uniq
      "#{deliveries_based_price_info(bc.price, d_counts)} (#{short_price(bc.price)} x #{deliveries_count(d_counts)})".html_safe
    end
  end

  def basket_complement_label(bc)
    collection_text(bc.public_name, details: basket_complement_details(bc))
  end

  def depots_collection(membership: nil, data: {})
    visible_depots(membership).map { |d|
      details = []
      if deliveries_counts.many?
        if d.price.positive?
          details << "#{deliveries_based_price_info(d.price, d.deliveries_counts)} (#{short_price(d.price)} x #{deliveries_count(d.deliveries_counts)})"
        else
          details << deliveries_count(d.deliveries_counts)
        end
      elsif d.price.positive?
        details << "#{deliveries_based_price_info(d.price, d.deliveries_counts)} (#{t('helpers.price_per_delivery', price: short_price(d.price))})"
      end
      if address = d.full_address
        details << address
        icon = map_icon(address).html_safe
      elsif d.address.present?
        details << d.address
      end
      [
        collection_text(d.public_name,
          details: details.compact.join(', '),
          icon: icon),
        d.id,
        data: {
          form_choices_limiter_values_param: d.visible_deliveries_cycle_ids.join(',')
        }.merge(data)
      ]
    }
  end

  def visible_deliveries_cycles_collection(membership: nil, data: {})
    ids = visible_depots(membership).flat_map(&:visible_deliveries_cycle_ids)
    ids << membership.deliveries_cycle_id if membership
    DeliveriesCycle
      .where(id: ids.uniq)
      .to_a
      .sort_by { |dc| [dc.form_priority, -1 * dc.deliveries_count, dc.public_name] }
      .map { |dc|
        [
          collection_text(dc.public_name,
            details: deliveries_count(dc.deliveries_count)),
          dc.id,
          data: data
        ]
      }
  end

  def terms_of_service_label
    text =
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
    "<span class='flex-grow font-normal'>#{text}</span>".html_safe
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
    parts = []
    parts << content_tag(:i, current_session.email) unless current_session.admin_originated?
    parts += emails
    parts.join(', ').html_safe
  end

  def display_phones(member)
    parts = []
    member.phones_array.each do |phone|
      parts << phone_link(phone)
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
      ].compact.join('-')
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
    ids = Depot.visible.pluck(:id)
    ids << membership.depot_id if membership
    Depot
      .where(id: ids.uniq)
      .includes(:deliveries_cycles)
      .reorder('form_priority, price, name')
      .to_a
  end

  def deliveries_counts
    @deliveries_counts ||= visible_depots.map(&:deliveries_counts).flatten.uniq.sort
  end

  def depots_delivery_ids
    @depots_delivery_ids ||= visible_depots.map(&:current_and_future_delivery_ids)
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

  def collection_text(text, details: nil, icon: nil)
    txts = ["<div class='flex-grow flex flex-col'>"]
    txts << "<span class='text-sm font-medium text-gray-700 dark:text-gray-300'>#{text}</span>"
    if details.present?
      txts << "<span class='text-sm'>#{details}</span>"
    end
    txts << "</div>"
    if icon
      txts << "<div class='flex-none ml-2'>#{icon}</div>"
    end
    txts.join.html_safe
  end

  def map_icon(location)
    link_to "https://www.google.com/maps?q=#{location}", title: location, target: :blank, class: 'text-gray-300 dark:text-gray-700 hover:text-green-500' do
      inline_svg_tag 'members/map.svg', class: 'inline-block'
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

  def member_features_sentence
    features = []
    features << t_activity('.features.activity_text') if Current.acp.feature?('activity')
    features << t('.features.absence_text') if Current.acp.feature?('absence')
    features << t('.features.deliveries_text')
    features << t('.features.billing_text')
    features.to_sentence
  end
end
