# frozen_string_literal: true

module MembersHelper
  def notice_pane(icon_name = nil, &block)
    content_tag :div, class: "mb-4 flex items-center gap-2 rounded border-1 border-dashed border-teal-500 bg-teal-100 p-2 text-teal-700 hover:bg-teal-200 dark:bg-teal-900 dark:text-teal-300 hover:dark:bg-teal-800" do
      concat icon(icon_name, class: "size-5 w-8 shrink-0") if icon_name
      concat content_tag(:span, capture(&block))
    end
  end

  def link_with_session(member, session)
    content_tag(:span) {
      link = auto_link(member).html_safe
      if session && (!session.admin_id? && session.email)
        link += content_tag(:span, class: "block text-sm text-gray-500", title: Session.human_attribute_name(:email_session)) {
          session.email
        }
      end
      link
    }
  end

  def with_note_icon(note)
    if note.present?
      id = SecureRandom.hex(6)
      Arbre::Context.new({}, self) do
        div class: "flex items-center justify-between" do
          div yield
          div helpers.tooltip(id, note, icon_name: "chat-bubble-bottom-center-text")
        end
      end.html_safe
    else
      yield
    end
  end

  def members_collection(relation)
    member_ids = @collection_before_scope.distinct.pluck(:member_id)
    Member.where(id: member_ids).order_by_name
  end

  def languages_collection
    Current.org.languages.map { |l| [ t("languages.#{l}"), l ] }
  end

  def organization_billing_year_divisions_collection(data: {}, membership: nil)
    divisions = Current.org.billing_year_divisions

    # Still allow renewing with the current membership division
    if membership && divisions.exclude?(membership.billing_year_division)
      divisions << membership.billing_year_division
    end

    divisions.sort.map { |i|
      [
        I18n.t("billing.year_division.x#{i}"),
        i,
        data: data
      ]
    }
  end

  def basket_size_details(bs, force_default: false)
    return bs.form_detail if !force_default && bs.form_detail?

    @org_shares_numbers ||= BasketSize.visible.pluck(:shares_number).uniq
    details = []
    if bs.price.positive?
      details << "#{deliveries_based_price_info(bs.price, bs.billable_deliveries_counts)} (#{short_price(bs.price)} x #{deliveries_count(bs.billable_deliveries_counts)})"
    else
      details << deliveries_count(bs.billable_deliveries_counts)
    end
    details << activities_count(bs.activity_participations_demanded_annually)
    if @org_shares_numbers.size > 1
      details << shares_number(bs.shares_number)
    end
    details.compact.join(", ").html_safe
  end

  def basket_sizes_collection(membership: nil, no_basket_option: true, data: {}, no_basket_data: {})
    col = visible_basket_sizes(object: membership).map { |bs|
      [
        collection_text(bs.public_name, details: basket_size_details(bs)),
        bs.id,
        data: {
          form_min_value_min_value_param: bs.shares_number,
          activity: bs.activity_participations_demanded_annually
        }.merge(data)
      ]
    }
    if no_basket_option && (Current.org.member_support?)
      col << [
        collection_text(t("helpers.no_basket_size"),
          details:
            if Current.org.annual_fee? && Current.org.share?
              t("helpers.no_basket_size_annual_fee_and_share")
            elsif Current.org.annual_fee?
              t("helpers.no_basket_size_annual_fee")
            elsif Current.org.share?
              t("helpers.no_basket_size_share")
            end
        ),
        0,
        data: {
          form_min_value_min_value_param: Current.org.shares_number,
          activity: 0
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

  def basket_prices_extra_collection(data: {}, current_price_extra: nil)
    return unless Current.org.basket_price_extras?

    label_template = Liquid::Template.parse(Current.org.basket_price_extra_label)
    details_template = Liquid::Template.parse(Current.org.basket_price_extra_label_detail_or_default)
    extras = Current.org[:basket_price_extras]
    extras << current_price_extra if current_price_extra
    extras.map(&:to_f).uniq.compact.sort.map do |extra|
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
      counts = depots_delivery_cycles.map { |dc| dc.billable_deliveries_count_for(bc) }.uniq
      details << "#{deliveries_based_price_info(bc.price, counts)} (#{short_price(bc.price)} x #{deliveries_count(counts)})".html_safe
    end
    details << activities_count(bc.activity_participations_demanded_annually)
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
      [
        collection_text(d.public_name,
          details: depot_details(d, show_price: show_price, only_price_per_delivery: only_price_per_delivery),
          icon: d.full_address && map_icon(d.full_address).html_safe),
        d.id,
        data: {
          form_choices_limiter_values_param: d.delivery_cycle_ids.join(",")
        }.merge(data)
      ]
    }
  end

  def depot_details(d, show_price: true, only_price_per_delivery: false)
    return d.form_detail if d.form_detail?

    details = []
    if show_price
      if only_price_per_delivery
        if d.price.positive?
          details << "#{t('helpers.price_per_delivery', price: short_price(d.price))}"
        end
      elsif billable_deliveries_counts.many?
        if d.price.positive?
          details << "#{deliveries_based_price_info(d.price, d.billable_deliveries_counts)} (#{short_price(d.price)} x #{deliveries_count(d.billable_deliveries_counts)})"
        elsif d.delivery_cycles != depots_delivery_cycles
          details << deliveries_count(d.billable_deliveries_counts)
        end
      elsif d.price.positive?
        details << "#{deliveries_based_price_info(d.price, d.billable_deliveries_counts)} (#{t('helpers.price_per_delivery', price: short_price(d.price))})"
      end
    end
    if address = d.full_address
      details << address
    elsif d.street.present?
      details << d.street
    end
    details.compact.join(", ").html_safe
  end

  def delivery_cycle_details(dc, force_default: false)
    return dc.form_detail if !force_default && dc.form_detail?

    details = []
    if dc.price.positive?
      counts = [ dc.billable_deliveries_count ]
      details << "#{deliveries_based_price_info(dc.price, counts)} (#{short_price(dc.price)} x #{deliveries_count(counts)})"
    else
      details << deliveries_count(dc.billable_deliveries_count)
    end
    absences_included_text = t("helpers.absences_included", count: dc.absences_included_annually)
    if dc.absences_included_annually.positive? && dc.public_name.exclude?(absences_included_text)
      details << absences_included_text
    end
    details.compact.join(", ")
  end

  def visible_delivery_cycles_collection(membership: nil, only_with_future_deliveries: false, data: {})
    ids = visible_basket_sizes(object: membership).map(&:delivery_cycle_id).compact
    ids += visible_depots(object: membership).flat_map(&:delivery_cycle_ids)
    ids << membership.delivery_cycle_id if membership
    cycles = DeliveryCycle
      .where(id: ids.uniq)
      .kept
      .includes(:depots)
      .member_ordered
      .to_a

    if only_with_future_deliveries
      future_cycles = cycles.select { |d| d.future_deliveries_count.positive? }
      cycles = future_cycles if future_cycles.any?
      checked_id =
        cycles.find { |dc| dc.id == membership&.delivery_cycle_id }&.id ||
        cycles.find { |dc| dc.depots.include?(membership&.depot) }&.id ||
        cycles.first&.id
    end

    cycles.map { |dc|
      [
        collection_text(dc.public_name, details: delivery_cycle_details(dc)),
        dc.id,
        data: data,
        checked: dc.id == checked_id
      ]
    }
  end

  def terms_of_service_label
    docs = []
    if Current.org.charter_url
      docs << document_link(:charter, Current.org.charter_url)
    end
    if Current.org.statutes_url
      docs << document_link(:statutes, Current.org.statutes_url)
    end
    if Current.org.terms_of_service_url
      docs << document_link(:terms_of_service, Current.org.terms_of_service_url)
    end
    if Current.org.privacy_policy_url
      docs << document_link(:privacy_policy, Current.org.privacy_policy_url)
    end

    content_tag :span, class: "grow font-normal" do
      t(".terms_of_service_html", documents: docs.to_sentence.html_safe)
    end
  end

  def document_link(type, url)
    link_to t(".documents.#{type}"), url, target: "_blank", class: "underline text-green-500 hover:text-green-500"
  end

  def display_address(member)
    [
      member.street,
      "#{member.zip} #{member.city}"
    ].join("</br>").html_safe
  end

  def display_billing_address(member)
    parts = [
      member.billing_info(:street),
      "#{member.billing_info(:zip)} #{member.billing_info(:city)}"
    ]
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

  def display_shares_number(member)
    parts = []
    if member.existing_shares_number&.positive?
      parts << t(".shares_number.existing", count: member.existing_shares_number)
    end
    invoiced_number = member.invoices.not_canceled.share.sum(:shares_number)
    if invoiced_number.positive?
      parts << link_to(
        t(".shares_number.invoiced", count: invoiced_number),
        invoices_path(q: { member_id_eq: member.id, entity_type_in: "Share" }, scope: :all))
    end
    if member.missing_shares_number.positive?
      parts << t(".shares_number.missing", count: member.missing_shares_number)
    end
    txt = parts.to_sentence.html_safe
    if member.shares_number > member.required_shares_number
      sign = member.required_shares_number.negative? ? "-" : ""
      txt += " (#{sign}#{t('.shares_number.required', count: member.required_shares_number.abs)})"
    end
    txt
  end

  def deliveries_based_price_info(price, counts = billable_deliveries_counts)
    if counts.many?
      range = [
        counts.min * price,
        counts.max * price
      ].map { |p| price_info(p, format: "%n") }
      cur(range.compact.join("-"))
    else
      price_info(counts.first.to_i * price)
    end
  end

  def deliveries_count_range(counts = billable_deliveries_counts)
    if counts.many?
      [ counts.min, counts.max ].uniq.join("-")
    else
      counts.first.to_i
    end
  end

  private

  def deliveries_count(counts = billable_deliveries_counts)
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
      futures_depots = depots.select { |d| d.future_deliveries_counts.any?(&:positive?) }
      if futures_depots.any?
        depots = futures_depots
      end
    end

    depots
  end

  def billable_deliveries_counts
    @billable_deliveries_counts ||=
      (visible_basket_sizes + visible_depots).map(&:billable_deliveries_counts).flatten.uniq.sort
  end

  def depots_delivery_cycles
    @depots_delivery_cycles ||= visible_depots.flat_map(&:delivery_cycles).uniq
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
    txts = [ "<div class='grow flex flex-col'>" ]
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
    link_to "https://www.google.com/maps?q=#{location}", title: location, target: :blank do
      icon "map", class: "inline-block text-gray-300 dark:text-gray-700 hover:text-green-500"
    end
  end

  def activities_count(count)
    return unless feature?("activity")
    return if count.zero?

    t_activity("helpers.activities_count_per_year", count: count).gsub(/\s/, "&nbsp;")
  end

  def shares_number(number)
    return unless number

    t("helpers.shares_number", count: number)
  end

  def member_features_sentence
    features = []
    features << t_activity(".features.activity_text") if feature?("activity")
    features << t(".features.absence_text") if feature?("absence")
    features << t(".features.deliveries_text")
    features << t(".features.billing_text")
    features.to_sentence
  end

  def member_information_title
    Current.org.member_information_title.presence || t("members.information.default_title")
  end
end
