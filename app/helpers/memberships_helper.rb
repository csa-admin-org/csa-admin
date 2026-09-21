# frozen_string_literal: true

module MembershipsHelper
  def basket_description(basket, text_only: false)
    parts = [ basket_size_description(basket, text_only: text_only) ]
    if basket.baskets_basket_complements.any?
      parts << basket_complements_description(basket.baskets_basket_complements, text_only: text_only)
    end
    parts.join(" + ").html_safe
  end

  def display_period(range, format: :number)
    [ range.min, range.max ].map { |d|
      I18n.l(d, format: format)
    }.join(" – ")
  end

  def basket_size_description(object, text_only: false, public_name: true)
    case object
    when Basket, Membership
      object.basket_description(public_name: public_name)
    else
      content_tag(:em, t("activerecord.models.basket_size.none"), class: "muted-data") unless text_only
    end
  end

  def basket_complements_description(complements, text_only: false, public_name: true)
    complements =
      Array(complements)
        .compact
        .sort_by { |c|
          public_name ? c.basket_complement.public_name : c.basket_complement.name
        }
    names = complements.map { |c| c.description(public_name: public_name) }
    if names.present?
      names.to_sentence
    elsif !text_only
      content_tag :em, t("activerecord.models.basket_complement.none"), class: "muted-data"
    end
  end

  def basket_sizes_price_info(membership, baskets)
    baskets
      .billable
      .pluck(:quantity, :basket_size_price)
      .select { |_, p| p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, bbs|
        "#{bbs.sum { |q, _| q }}x #{precise_cur(price).strip}"
      }.join(" + ").html_safe
  end

  def show_basket_price_extras?
    feature?("basket_price_extra")
      && Current.org.basket_price_extra_public_title.present?
      && Current.org.basket_price_extras?
  end

  def basket_price_extra_feature_or_used?
    feature?("basket_price_extra") || Membership.basket_price_extra_used?
  end

  def basket_price_extra_for?(record)
    feature?("basket_price_extra") || basket_price_extra_present?(record)
  end

  def basket_price_extra_present?(record)
    case record
    when Basket
      record.price_extra&.nonzero?
    when Membership
      record.basket_price_extra&.nonzero? ||
        record.baskets.any? { |b| b.price_extra.nonzero? }
    else
      false
    end
  end

  def show_activity_participations?
    feature?("activity") && Current.org.activity_participations_form?
  end

  def activity_participations_form_detail(force_default: false)
    if !force_default && Current.org.activity_participations_form_detail?
      Current.org.activity_participations_form_detail
    elsif Current.org.activity_participations_form_min && Current.org.activity_participations_form_max
      t("activity_participations.form_detail.min_max", price: cur(Current.org.activity_price))
    elsif Current.org.activity_participations_form_min
      t("activity_participations.form_detail.min", price: cur(Current.org.activity_price))
    elsif Current.org.activity_participations_form_max
      t("activity_participations.form_detail.max", price: cur(Current.org.activity_price))
    end
  end

  def activity_participations_demanded_preview(value, input_id: "membership_activity_participations_demanded")
    text = t("active_admin.resource.form.activity_participations_demanded_logic")
    tooltip_id = "tooltip-#{input_id}"
    content_tag(
      :div,
      class: "activity-participations-demanded tooltip-wrap",
      data: { controller: "tooltip", tooltip_dismissible_value: true }
    ) do
      content_tag(
        :span,
        class: "tooltip-trigger is-clickable",
        tabindex: 0,
        role: "button",
        data: {
          "tooltip-target" => "trigger",
          action: "click->tooltip#toggle mouseenter->tooltip#preview mouseleave->tooltip#hidePreview focus->tooltip#preview blur->tooltip#hidePreview"
        },
        aria: { describedby: tooltip_id, controls: tooltip_id, expanded: false },
        onclick: "event.stopPropagation()"
      ) {
        tag.input(
          type: "text",
          id: input_id,
          value: value,
          disabled: true,
          tabindex: -1,
          aria: { label: Membership.human_attribute_name(:activity_participations_demanded) },
          data: { form_activity_participations_target: "demanded" })
      } + tooltip_element(text, id: tooltip_id)
    end
  end

  def activity_participations_formula_display(annually, demanded)
    annually = activity_participations_placeholder(annually)
    demanded = activity_participations_placeholder(demanded)
    return if annually.nil? && demanded.nil?

    content_tag(:span, class: "cluster is-snug is-nowrap activity-participations-formula-text") do
      safe_join([
        content_tag(:span, annually, class: "tabular-nums"),
        icon("move-right", class: "activity-participations-formula-arrow"),
        content_tag(:span, demanded, class: "tabular-nums")
      ])
    end
  end

  def activity_participations_demanded_logic_settings_url
    if authorized?(:update, Organization)
      edit_organization_path(:activity, anchor: "activity_participations_demanded_logic")
    else
      organization_path(anchor: "activity")
    end
  end

  def activity_participations_demanded_formula_hint
    t("formtastic.hints.membership.activity_participations_demanded_formula_html",
      settings_url: activity_participations_demanded_logic_settings_url)
  end

  def absences_included_logic_settings_url
    if authorized?(:update, Organization)
      edit_organization_path(:absence, anchor: "absences_included_logic")
    else
      organization_path(anchor: "absence")
    end
  end

  def absences_included_formula_hint
    t("formtastic.hints.membership.absences_included_annually_formula_html",
      settings_url: absences_included_logic_settings_url,
      handbook_url: handbook_page_path("absence", anchor: "absence-included"))
  end

  def absences_included_preview(value, input_id: "membership_absences_included")
    text = t("active_admin.resource.form.absences_included_logic")
    tooltip_id = "tooltip-#{input_id}"
    content_tag(
      :div,
      class: "admin-formula-result tooltip-wrap",
      data: { controller: "tooltip", tooltip_dismissible_value: true }
    ) do
      content_tag(
        :span,
        class: "tooltip-trigger is-clickable",
        tabindex: 0,
        role: "button",
        data: {
          "tooltip-target" => "trigger",
          action: "click->tooltip#toggle mouseenter->tooltip#preview mouseleave->tooltip#hidePreview focus->tooltip#preview blur->tooltip#hidePreview"
        },
        aria: { describedby: tooltip_id, controls: tooltip_id, expanded: false },
        onclick: "event.stopPropagation()"
      ) {
        tag.input(
          type: "text",
          id: input_id,
          value: value,
          disabled: true,
          tabindex: -1,
          aria: { label: Membership.human_attribute_name(:absences_included) },
          data: { form_absences_included_target: "included" })
      } + tooltip_element(text, id: tooltip_id)
    end
  end

  def basket_price_extra_dynamic_pricing_settings_url
    if authorized?(:update, Organization)
      edit_organization_path(:basket_price_extra, anchor: "basket_price_extra_dynamic_pricing")
    else
      organization_path(anchor: "basket_price_extra")
    end
  end

  def basket_price_extra_formula_hint
    t("formtastic.hints.membership.basket_price_extra_formula_html",
      settings_url: basket_price_extra_dynamic_pricing_settings_url)
  end

  def basket_price_extra_preview(value, input_id: "membership_calculated_price_extra")
    text = t("active_admin.resource.form.basket_price_extra_dynamic_pricing")
    tooltip_id = "tooltip-#{input_id}"
    content_tag(
      :div,
      class: "admin-formula-result admin-formula-result-money tooltip-wrap",
      data: { controller: "tooltip", tooltip_dismissible_value: true }
    ) do
      content_tag(
        :span,
        class: "tooltip-trigger is-clickable",
        tabindex: 0,
        role: "button",
        data: {
          "tooltip-target" => "trigger",
          action: "click->tooltip#toggle mouseenter->tooltip#preview mouseleave->tooltip#hidePreview focus->tooltip#preview blur->tooltip#hidePreview"
        },
        aria: { describedby: tooltip_id, controls: tooltip_id, expanded: false },
        onclick: "event.stopPropagation()"
      ) {
        tag.input(
          type: "text",
          id: input_id,
          value: value,
          disabled: true,
          tabindex: -1,
          aria: { label: t("active_admin.resource.form.basket_price_extra_dynamic_pricing") },
          data: { form_basket_price_extra_target: "billedExtra" })
      } + tooltip_element(text, id: tooltip_id)
    end
  end

  def basket_price_extra_preview_payload(extra:, basket_size_id:, basket_size_price:, complements_price:, deliveries_count:)
    extra = extra.to_f
    basket_size_id = basket_size_id.presence&.to_i
    basket_size_price = basket_size_price.to_f
    complements_price = complements_price.to_f
    billed =
      if extra.zero? || (basket_size_price.zero? && complements_price.zero?)
        0
      else
        Current.org.calculate_basket_price_extra(
          extra,
          basket_size_price,
          basket_size_id,
          complements_price,
          deliveries_count)
      end
    { billed_extra: cur(billed) }
  end

  def basket_price_extra_preview_from_membership_record(membership)
    year = membership.started_on ? membership.fy_year : Current.fiscal_year.year
    basket_price_extra_preview_payload(
      extra: membership.basket_price_extra,
      basket_size_id: membership.basket_size_id,
      basket_size_price: membership.basket_size_price.nil? ? membership.basket_size&.price : membership.basket_size_price,
      complements_price: basket_price_extra_complements_price_from(
        membership.memberships_basket_complements),
      deliveries_count: Current.org.deliveries_count(year))
  end

  def basket_price_extra_preview_from_waiting_member(member)
    started_on = member.fresh_waiting_membership_started_on || member.waiting_membership_start_on
    year = started_on ? Current.org.fiscal_year_for(started_on).year : Current.fiscal_year.year
    complements_price = member.members_basket_complements.reject(&:marked_for_destruction?).sum { |comp|
      next 0 if comp.basket_complement_id.blank?

      comp.quantity.to_i * comp.basket_complement&.price.to_f
    }
    basket_price_extra_preview_payload(
      extra: member.waiting_basket_price_extra,
      basket_size_id: member.waiting_basket_size_id,
      basket_size_price: member.waiting_basket_size&.price,
      complements_price: complements_price,
      deliveries_count: Current.org.deliveries_count(year))
  end

  def basket_price_extra_preview_from_basket_record(basket)
    basket_price_extra_preview_payload(
      extra: basket.price_extra,
      basket_size_id: basket.basket_size_id,
      basket_size_price: basket.basket_size_price.nil? ? basket.basket_size&.price : basket.basket_size_price,
      complements_price: basket_price_extra_complements_price_from(
        basket.baskets_basket_complements),
      deliveries_count: Current.org.deliveries_count(basket.membership.fy_year))
  end

  def basket_price_extra_preview_from_membership(raw)
    attrs = activity_participations_preview_attrs(raw)
    extra = attrs[:basket_price_extra]
    size_id = attrs[:basket_size_id]
    started_on = basket_price_extra_parse_date(attrs[:started_on])
    year = started_on ? Current.org.fiscal_year_for(started_on).year : Current.fiscal_year.year
    basket_price_extra_preview_payload(
      extra: extra,
      basket_size_id: size_id,
      basket_size_price: basket_price_extra_preview_size_price(attrs),
      complements_price: basket_price_extra_preview_complements_price(
        attrs[:memberships_basket_complements_attributes]),
      deliveries_count: Current.org.deliveries_count(year))
  end

  def basket_price_extra_preview_from_waiting(raw)
    attrs = activity_participations_preview_attrs(raw)
    extra = attrs[:waiting_basket_price_extra]
    size_id = attrs[:waiting_basket_size_id]
    started_on = basket_price_extra_parse_date(attrs[:waiting_membership_started_on])
    year = started_on ? Current.org.fiscal_year_for(started_on).year : Current.fiscal_year.year
    basket_price_extra_preview_payload(
      extra: extra,
      basket_size_id: size_id,
      basket_size_price: BasketSize.find_by(id: size_id)&.price,
      complements_price: basket_price_extra_preview_complements_price(
        attrs[:members_basket_complements_attributes]),
      deliveries_count: Current.org.deliveries_count(year))
  end

  def basket_price_extra_preview_from_basket(raw, year: nil)
    attrs = activity_participations_preview_attrs(raw)
    extra = attrs[:price_extra]
    size_id = attrs[:basket_size_id]
    year ||= Current.fiscal_year.year
    basket_price_extra_preview_payload(
      extra: extra,
      basket_size_id: size_id,
      basket_size_price: basket_price_extra_preview_size_price(attrs),
      complements_price: basket_price_extra_preview_complements_price(
        attrs[:baskets_basket_complements_attributes]),
      deliveries_count: Current.org.deliveries_count(year))
  end

  def activity_participations_default_annually(membership)
    if membership.basket_size
      membership.activity_participations_demanded_annually_by_default
    else
      shared_activity_participations_demanded_annually
    end
  end

  def activity_participations_automatic_price_change(membership, demanded: nil)
    return unless membership.member && membership.basket_size && membership.delivery_cycle
    return unless membership.started_on && membership.ended_on

    demanded = activity_participations_computed_demanded(membership) if demanded.nil?
    return if demanded.nil?

    copy = membership.dup
    copy.activity_participations_demanded_annually = membership.activity_participations_demanded_annually_by_default
    default_demanded = ActivityParticipationDemanded.new(copy).count
    -(demanded - default_demanded) * Current.org.activity_price
  end

  def activity_participations_computed_demanded(membership)
    return unless membership.member && membership.basket_size && membership.delivery_cycle
    return unless membership.started_on && membership.ended_on

    ActivityParticipationDemanded.new(membership).count
  end

  def activity_participations_preview_payload(membership)
    demanded = activity_participations_computed_demanded(membership)
    price = activity_participations_automatic_price_change(membership, demanded: demanded)
    {
      default_annually: activity_participations_placeholder(activity_participations_default_annually(membership)),
      demanded: activity_participations_placeholder(demanded),
      default_price_change: activity_participations_placeholder(price)
    }
  end

  def absences_included_preview_payload(membership)
    copy = membership.dup
    absences_included_assign_annually(copy, membership.absences_included_annually)
    {
      default_annually: activity_participations_placeholder(
        membership.delivery_cycle&.absences_included_annually),
      included: activity_participations_placeholder(
        AbsencesIncluded.new(copy).preview_count)
    }
  end

  def absences_included_preview_membership(raw)
    attrs = activity_participations_preview_attrs(raw)
    membership = Membership.new
    membership.assign_attributes(attrs.slice(
      :basket_size_id, :depot_id, :delivery_cycle_id, :started_on, :ended_on))
    absences_included_assign_annually(membership, attrs[:absences_included_annually])
    membership
  end

  def activity_participations_placeholder(value)
    return if value.nil?

    value == value.to_i ? value.to_i : value
  end

  def activity_participations_preview_membership(raw)
    attrs = activity_participations_preview_attrs(raw)
    membership = Membership.new
    membership.assign_attributes(attrs.slice(
      :member_id, :basket_size_id, :basket_quantity,
      :depot_id, :delivery_cycle_id, :started_on, :ended_on))
    membership.member ||= Member.new(
      salary_basket: ActiveRecord::Type::Boolean.new.cast(attrs[:salary_basket]))
    activity_participations_assign_complements(
      membership, attrs[:memberships_basket_complements_attributes])
    activity_participations_assign_annually(
      membership, attrs[:activity_participations_demanded_annually])
    membership
  end

  def activity_participations_preview_from_waiting(raw)
    attrs = activity_participations_preview_attrs(raw)
    membership = Membership.new
    membership.member = Member.new(
      salary_basket: ActiveRecord::Type::Boolean.new.cast(attrs[:salary_basket]))
    membership.basket_size_id = attrs[:waiting_basket_size_id]
    membership.basket_quantity = 1
    membership.depot_id = attrs[:waiting_depot_id]
    membership.delivery_cycle_id = attrs[:waiting_delivery_cycle_id]
    activity_participations_assign_complements(
      membership, attrs[:members_basket_complements_attributes])
    activity_participations_assign_waiting_period(
      membership, attrs[:waiting_membership_started_on])
    activity_participations_assign_annually(
      membership, attrs[:waiting_activity_participations_demanded_annually])
    membership
  end

  def activity_participations_preview_from_waiting_member(member)
    membership = Membership.new
    membership.member = member
    membership.basket_size_id = member.waiting_basket_size_id
    membership.basket_quantity = 1
    membership.depot_id = member.waiting_depot_id
    membership.delivery_cycle_id = member.waiting_delivery_cycle_id
    member.members_basket_complements.reject(&:marked_for_destruction?).each do |mbc|
      next if mbc.basket_complement_id.blank?

      membership.memberships_basket_complements.build(
        basket_complement_id: mbc.basket_complement_id,
        quantity: mbc.quantity.presence || 1)
    end
    started_on = member.fresh_waiting_membership_started_on || member.waiting_membership_start_on
    membership.started_on = started_on
    membership.ended_on = member.waiting_membership_end_on(started_on)
    activity_participations_assign_annually(
      membership, member.waiting_activity_participations_demanded_annually)
    membership
  end

  def activity_participations_annually_form_value(current, default)
    return if current.nil?
    return if !default.nil? && current.to_i == default.to_i

    current
  end

  def activity_participations_price_change_form_value(membership)
    current = membership.activity_participations_annual_price_change
    return if current.nil?

    automatic = activity_participations_automatic_price_change(membership)
    return current if automatic.nil?

    current unless current.to_d == automatic.to_d
  end

  def baskets_price_extra_info(membership, baskets, highlight: false)
    label_grouped =
      baskets
        .reject { |b| b.price_extra.zero? }
        .group_by(&:price_extra)
        .sort
    label_grouped.map { |price_extra, bbs|
      grouped =
        bbs
          .reject { |b| b.calculated_price_extra.zero? }
          .group_by(&:calculated_price_extra)
          .sort
      info = grouped.map { |calculated_price_extra, bbs|
        price = precise_cur(calculated_price_extra).strip
        "#{bbs.sum(&:quantity)}x #{price}"
      }.join(" + ")

      if Current.org.basket_price_extra_dynamic_pricing?
        label_template = Liquid::Template.parse(Current.org.basket_price_extra_label)
        label = label_template.render("extra" => price_extra).strip
        if highlight
          label = content_tag(:strong, label)
        end
        info = "#{info}, #{label}"
      end

      info
    }.join(" + ").html_safe
  end

  def membership_basket_complements_price_info(membership)
    membership.baskets
      .billable
      .joins(baskets_basket_complements: :basket_complement)
      .pluck("baskets_basket_complements.quantity", "baskets_basket_complements.price")
      .group_by { |_, price| price }
      .sort
      .map { |price, bbcs|
        "#{bbcs.sum { |q, _| q }}x #{precise_cur(price)}"
      }.join(" + ").html_safe
  end

  def basket_complement_price_info(membership, basket_complement)
    membership.baskets
      .billable
      .joins(baskets_basket_complements: :basket_complement)
      .where(baskets_basket_complements: { basket_complement: basket_complement })
      .pluck("baskets_basket_complements.quantity", "baskets_basket_complements.price")
      .group_by { |_, price| price }
      .sort
      .map { |price, bbcs|
        "#{bbcs.sum { |q, _| q }}x #{precise_cur(price)}"
      }.join(" + ").html_safe
  end

  def depots_price_info(baskets)
    baskets
      .billable
      .pluck(:quantity, :depot_price)
      .select { |q, p| q.positive? && p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, baskets|
        "#{baskets.sum { |q, _| q }}x #{precise_cur(price)}"
      }.join(" + ").html_safe
  end

  def delivery_cycle_price_info(baskets)
    baskets
      .countable
      .map { |b| [ b.quantity, b.delivery_cycle_price ] }
      .select { |q, p| q.positive? && p.positive? }
      .group_by { |_, p| p }
      .sort
      .map { |price, baskets|
        "#{baskets.sum { |q, _| q }}x #{precise_cur(price)}"
      }.join(" + ").html_safe
  end

  def renewal_decisions_collection
    [
      [
        content_tag(:span, class: "renewal-option") {
          content_tag(:span, t("members.memberships.renewal.options.renew"),
            class: "") +
          content_tag(:span, t("members.memberships.renewal.options.renew_hint"),
            class: "hint text-sm muted-data")
        }.html_safe,
        :renew
      ],
      [ t("members.memberships.renewal.options.cancel"), :cancel ]
    ]
  end

  def display_basket_price_extra_raw(membership)
    return unless membership.basket_price_extra&.positive?

    if Current.org.basket_price_extra_dynamic_pricing?
      membership.basket_price_extra.to_i
    else
      cur(membership.basket_price_extra)
    end
  end

  def membership_delivery_summary(membership)
    parts = [
      link_to(
        "#{membership.baskets_count} #{Delivery.model_name.human(count: membership.baskets_count)}",
        members_deliveries_path
      )
    ]
    if membership.trial? && !membership.canceled?
      parts << t("members.memberships.membership.remaining_trial_baskets_count",
        count: membership.remaining_trial_baskets_count)
    end
    if feature?("absence") && membership.baskets.absent.any?
      parts << link_to(
        t("members.memberships.membership.absent_baskets_count", count: membership.baskets.absent.count),
        members_absences_path
      )
    end
    safe_join(parts, ", ")
  end

  private

  def precise_cur(number)
    precision = number.to_s.split(".").last.size > 2 ? 3 : 2
    cur(number, unit: false, precision: precision).strip
  end

  def shared_activity_participations_demanded_annually
    values = BasketSize.kept.map(&:activity_participations_demanded_annually).uniq
    values.first if values.one?
  end

  def activity_participations_preview_attrs(raw)
    if raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h.with_indifferent_access
    else
      (raw || {}).to_h.with_indifferent_access
    end
  end

  def activity_participations_assign_complements(membership, nested)
    Array(nested&.values).each do |comp|
      next if ActiveRecord::Type::Boolean.new.cast(comp[:_destroy])
      next if comp[:basket_complement_id].blank?

      membership.memberships_basket_complements.build(
        basket_complement_id: comp[:basket_complement_id],
        quantity: comp[:quantity].presence || 1)
    end
  end

  def activity_participations_assign_annually(membership, raw_annually)
    annually =
      if raw_annually.to_s.strip == ""
        activity_participations_default_annually(membership)
      else
        raw_annually
      end
    membership.activity_participations_demanded_annually = annually unless annually.nil?
  end

  def basket_price_extra_preview_size_price(attrs)
    if attrs[:basket_size_price].to_s.strip == ""
      BasketSize.find_by(id: attrs[:basket_size_id])&.price
    else
      attrs[:basket_size_price]
    end
  end

  def basket_price_extra_preview_complements_price(nested)
    Array(nested&.values).sum { |comp|
      next 0 if ActiveRecord::Type::Boolean.new.cast(comp[:_destroy])
      next 0 if comp[:basket_complement_id].blank?

      price =
        if comp[:price].to_s.strip == ""
          BasketComplement.find_by(id: comp[:basket_complement_id])&.price
        else
          comp[:price]
        end
      (comp[:quantity].presence || 1).to_i * price.to_f
    }
  end

  def basket_price_extra_complements_price_from(records)
    records.reject(&:marked_for_destruction?).sum { |comp|
      next 0 if comp.basket_complement_id.blank?

      price = comp.price.nil? ? comp.basket_complement&.price : comp.price
      comp.quantity.to_i * price.to_f
    }
  end

  def basket_price_extra_parse_date(raw)
    Date.parse(raw.to_s) if raw.present?
  rescue Date::Error
    nil
  end

  def absences_included_assign_annually(membership, raw_annually)
    annually =
      if raw_annually.to_s.strip == ""
        membership.delivery_cycle&.absences_included_annually
      else
        raw_annually
      end
    membership.absences_included_annually = annually unless annually.nil?
  end

  def activity_participations_assign_waiting_period(membership, raw_started_on)
    started_on =
      begin
        Date.parse(raw_started_on.to_s) if raw_started_on.present?
      rescue Date::Error
        nil
      end
    started_on ||= waiting_preview_start_on(membership.delivery_cycle)
    membership.started_on = started_on
    membership.ended_on = Current.org.fiscal_year_for(started_on).end_of_year if started_on
  end

  def waiting_preview_start_on(delivery_cycle)
    next_delivery = delivery_cycle&.next_delivery
    return unless next_delivery

    [
      Date.current,
      next_delivery.fy_range.min,
      next_delivery.date.beginning_of_week
    ].max
  end
end
