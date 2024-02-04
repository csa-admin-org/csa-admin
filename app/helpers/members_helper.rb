module MembersHelper
  def link_with_session(member, session)
    content_tag(:span, class: "link-with-session") {
      link = auto_link(member).html_safe
      if session && (!session.admin_id? && session.email)
        link += content_tag(:span, class: "session-email", title: Session.human_attribute_name(:email_session)) {
          "(#{session.email})"
        }
      end
      link
    }
  end

  def with_note_icon(note)
    text = yield
    if note.present?
      content_tag(:span, class: "note-icon") {
        content_tag(:span, text) +
        content_tag(:span, class: "inline-block tooltip-toggle", data: { tooltip: note }) {
          inline_svg_tag "members/chat-note.svg", size: "20"
        }
      }.html_safe
    else
      text
    end
  end

  def languages_collection
    Current.acp.languages.map { |l| [ t("languages.#{l}"), l ] }
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
    return bs.form_detail if !force_default && bs.form_detail?

    @acp_shares_numbers ||= BasketSize.visible.pluck(:acp_shares_number).uniq
    details = []
    if bs.price.positive?
      details << "#{deliveries_based_price_info(bs.price, bs.deliveries_counts)} (#{short_price(bs.price)} x #{deliveries_count(bs.deliveries_counts)})"
    else
      details << deliveries_count(bs.deliveries_counts)
    end
    details << activities_count(bs.activity_participations_demanded_annualy)
    if @acp_shares_numbers.size > 1
      details << acp_shares_number(bs.acp_shares_number)
    end
    details.compact.join(", ").html_safe
  end

  def basket_sizes_collection(membership: nil, no_basket_option: true, data: {}, no_basket_data: {})
    col = visible_basket_sizes(object: membership).map { |bs|
      [
        collection_text(bs.public_name, details: basket_size_details(bs)),
        bs.id,
        data: {
          form_min_value_enforcer_min_value_param: bs.acp_shares_number
        }.merge(data)
      ]
    }
    if no_basket_option && (Current.acp.member_support?)
      col << [
        collection_text(t("helpers.no_basket_size"),
          details:
            if Current.acp.annual_fee
              t("helpers.no_basket_size_annual_fee")
            elsif Current.acp.share?
              t("helpers.no_basket_size_acp_share")
            end
        ),
        0,
        data: {
          form_min_value_enforcer_min_value_param: Current.acp.shares_number
        }.merge(no_basket_data)
      ]
    end
    col
  end

  def baskets_basket_complements(basket)
    complements = basket.delivery.basket_complements.visible.member_ordered
    basket_complements = basket.complements
    complements.each do |complement|
      unless complement.in?(basket_complements)
        basket.baskets_basket_complements.build(
          quantity: 0,
          basket_complement: complement)
      end
    end
    basket.baskets_basket_complements
  end

  def basket_prices_extra_collection(data: {})
    return unless Current.acp.basket_price_extras?

    label_template = Liquid::Template.parse(Current.acp.basket_price_extra_label)
    details_template = Liquid::Template.parse(Current.acp.basket_price_extra_label_detail_or_default)
    Current.acp[:basket_price_extras].map do |extra|
      full_year_price = deliveries_based_price_info(extra) if extra.positive?
      details = details_template.render(
        "extra" => extra,
        "full_year_price" => full_year_price)

      text = collection_text(label_template.render("extra" => extra).strip, details: details)
      [ text, extra, data: data ]
    end
  end

  def basket_complement_details(bc, force_default: false, only_price_per_delivery: false)
    return bc.form_detail if !force_default && bc.form_detail?

    details = []
    if only_price_per_delivery
      details << t("helpers.price_per_delivery", price: short_price(bc.price))
    else
      d_counts = depots_delivery_ids.map { |d_ids|
        (d_ids & bc.delivery_ids).size
      }.uniq
      details << "#{deliveries_based_price_info(bc.price, d_counts)} (#{short_price(bc.price)} x #{deliveries_count(d_counts)})".html_safe
    end
    if bc.activity_participations_demanded_annualy.positive?
      details << activities_count(bc.activity_participations_demanded_annualy)
    end
    details.compact.join(", ").html_safe
  end

  def basket_complement_label(bc, only_price_per_delivery: false)
    collection_text(bc.public_name, details: basket_complement_details(bc, only_price_per_delivery: only_price_per_delivery))
  end

  def depots_collection(depots: nil, membership: nil, basket: nil, delivery_cycle: nil, only_with_future_deliveries: false, show_price: true, only_price_per_delivery: false, data: {})
    (depots || visible_depots(
      object: membership || basket,
      delivery_cycle: delivery_cycle,
      only_with_future_deliveries: only_with_future_deliveries
    )).map { |d|
      details = []
      if show_price
        if only_price_per_delivery
          if d.price.positive?
            details << "#{t('helpers.price_per_delivery', price: short_price(d.price))}"
          end
        elsif deliveries_counts.many?
          if d.price.positive?
            details << "#{deliveries_based_price_info(d.price, d.deliveries_counts)} (#{short_price(d.price)} x #{deliveries_count(d.deliveries_counts)})"
          else
            details << deliveries_count(d.deliveries_counts)
          end
        elsif d.price.positive?
          details << "#{deliveries_based_price_info(d.price, d.deliveries_counts)} (#{t('helpers.price_per_delivery', price: short_price(d.price))})"
        end
      end
      if address = d.full_address
        details << address
        icon = map_icon(address).html_safe
      elsif d.address.present?
        details << d.address
      end
      [
        collection_text(d.public_name,
          details: details.compact.join(", "),
          icon: icon),
        d.id,
        data: {
          form_choices_limiter_values_param: d.delivery_cycle_ids.join(",")
        }.merge(data)
      ]
    }
  end

  def visible_delivery_cycles_collection(membership: nil, only_with_future_deliveries: false, data: {})
    ids = visible_basket_sizes(object: membership).map(&:delivery_cycle_id).compact
    ids += visible_depots(object: membership).flat_map(&:delivery_cycle_ids)
    ids << membership.delivery_cycle_id if membership
    cycles = DeliveryCycle
      .where(id: ids.uniq)
      .member_ordered
      .to_a

    if only_with_future_deliveries
      cycles = cycles.select { |d| d.future_deliveries_count.positive? }
    end

    cycles.map { |dc|
      [
        collection_text(dc.public_name,
          details: deliveries_count(dc.deliveries_count)),
        dc.id,
        data: data
      ]
    }
  end

  def terms_of_service_label
    docs = []
    if Current.acp.charter_url
      docs << document_link(:charter, Current.acp.charter_url)
    end
    if Current.acp.statutes_url
      docs << document_link(:statutes, Current.acp.statutes_url)
    end
    if Current.acp.terms_of_service_url
      docs << document_link(:terms_of_service, Current.acp.terms_of_service_url)
    end
    if Current.acp.privacy_policy_url
      docs << document_link(:privacy_policy, Current.acp.privacy_policy_url)
    end

    content_tag :span, class: "flex-grow font-normal" do
      t(".terms_of_service_html", documents: docs.to_sentence.html_safe)
    end
  end

  def document_link(type, url)
    link_to t(".documents.#{type}"), url, target: "_blank", class: "underline hover:text-green-500"
  end

  def display_address(member, country: true)
    parts = [
      member.address,
      "#{member.zip} #{member.city}"
    ]
    parts << member.country.translations[I18n.locale.to_s] if country
    parts.join("</br>").html_safe
  end

  def display_emails(member)
    emails = member.emails_array - [ current_session.email ]
    parts = emails
    parts << content_tag(:i, current_session.email) unless current_session.admin_originated?
    parts.join(", ").html_safe
  end

  def display_phones(member)
    parts = []
    member.phones_array.each do |phone|
      parts << phone_link(phone)
    end
    parts.join(", ").html_safe
  end

  def newsletter_unsubscribed?
    suppressions = EmailSuppression.unsuppressable.broadcast
    if Current.acp.mailchimp?
      suppressions = suppressions.where.not(origin: "Mailchimp")
    end
    suppressions.where(email: current_session.email).any?
  end

  def display_acp_shares_number(member)
    parts = []
    if member.existing_acp_shares_number&.positive?
      parts << t(".acp_shares_number.existing", count: member.existing_acp_shares_number)
    end
    invoiced_number = member.invoices.not_canceled.acp_share.sum(:acp_shares_number)
    if invoiced_number.positive?
      parts << link_to(
        t(".acp_shares_number.invoiced", count: invoiced_number),
        invoices_path(q: { member_id_eq: member.id, entity_type_in: "ACPShare" }, scope: :all))
    end
    if member.missing_acp_shares_number.positive?
      parts << t(".acp_shares_number.missing", count: member.missing_acp_shares_number)
    end
    txt = parts.to_sentence.html_safe
    if member.acp_shares_number > member.required_acp_shares_number
      txt += " (#{t('.acp_shares_number.required', count: member.required_acp_shares_number)})"
    end
    txt
  end

  def deliveries_based_price_info(price, counts = deliveries_counts)
    if counts.many?
      [
        price_info(counts.min * price),
        price_info(counts.max * price, format: "%n")
      ].compact.join("-")
    else
      price_info(counts.first.to_i * price)
    end
  end

  def deliveries_count_range(counts = deliveries_counts)
    if counts.many?
      [ counts.min, counts.max ].uniq.join("-")
    else
      counts.first.to_i
    end
  end

  def deliveries_count(counts = deliveries_counts)
    case counts
    when Array
      if counts.many?
        t("helpers.deliveries_counts_range", range: "#{counts.min}-#{counts.max}")
      else
        t("helpers.deliveries_count", count: counts.first.to_i)
      end
    when Integer
      t("helpers.deliveries_count", count: counts)
    end
  end

  private

  def visible_basket_sizes(object: nil)
    ids = BasketSize.visible.pluck(:id)
    ids << object.basket_size_id if object
    BasketSize
      .where(id: ids.uniq)
      .includes(:delivery_cycle)
      .member_ordered
      .to_a
  end

  def visible_depots(object: nil, delivery_cycle: nil, only_with_future_deliveries: false)
    ids = Depot.visible.pluck(:id)
    ids << object.depot_id if object
    depots = Depot
      .where(id: ids.uniq)
      .includes(:group, :delivery_cycles)
      .member_ordered
      .to_a

    if delivery_cycle
      new_depots = depots.select { |d| delivery_cycle.in?(d.delivery_cycles) }
      if new_depots.empty?
        depots = [ object&.depot || depots.first ]
      else
        depots = new_depots
      end
    end

    if only_with_future_deliveries
      depots = depots.select { |d| d.future_deliveries_counts.any?(&:positive?) }
    end

    depots
  end

  def deliveries_counts
    @deliveries_counts ||=
      (visible_basket_sizes + visible_depots).map(&:deliveries_counts).flatten.uniq.sort
  end

  def depots_delivery_ids
    @depots_delivery_ids ||= visible_depots.flat_map { |d|
      d.delivery_cycles.map(&:current_and_future_delivery_ids)
    }.uniq
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
    splitted = price.to_s.split(".")
    if splitted.many?
      decimals = splitted.last
      decimals.to_i == 0 ? 0 : [ decimals.length, 2 ].max
    else
      0
    end
  end

  def collection_text(text, details: nil, icon: nil)
    txts = [ "<div class='flex-grow flex flex-col'>" ]
    txts << "<span class='text-sm font-medium text-gray-700 dark:text-gray-300'>#{text}</span>"
    if details.present?
      txts << "<span class='text-sm'>#{details}</span>"
    end
    txts << "</div>"
    if icon
      txts << "<div class='flex-none ml-2 print:hidden'>#{icon}</div>"
    end
    txts.join.html_safe
  end

  def map_icon(location)
    link_to "https://www.google.com/maps?q=#{location}", title: location, target: :blank, class: "text-gray-300 dark:text-gray-700 hover:text-green-500" do
      inline_svg_tag "members/map.svg", class: "inline-block"
    end
  end

  def activities_count(count)
    return unless Current.acp.feature?("activity")

    t_activity("helpers.activities_count_per_year", count: count).gsub(/\s/, "&nbsp;")
  end

  def acp_shares_number(number)
    return unless number

    t("helpers.acp_shares_number", count: number)
  end

  def member_features_sentence
    features = []
    features << t_activity(".features.activity_text") if Current.acp.feature?("activity")
    features << t(".features.absence_text") if Current.acp.feature?("absence")
    features << t(".features.deliveries_text")
    features << t(".features.billing_text")
    features.to_sentence
  end

  def member_information_title
    Current.acp.member_information_title.presence || t("members.information.default_title")
  end
end
