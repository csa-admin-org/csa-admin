# frozen_string_literal: true

module AdminHelper
  def admin_member_card_type_options
    PriceReductionCard.order_by_name.map { |card|
      [ card.name, card.id, {
        data: {
          require_name: card.require_name?,
          require_number: card.require_number?,
          require_expires_on: card.require_expires_on?
        }
      } ]
    }
  end

  def member_card_input_options(visible, target)
    {
      required: true,
      wrapper_html: {
        class: ("is-hidden" unless visible),
        data: { form_member_card_target: target }
      },
      input_html: { disabled: !visible }
    }
  end

  def admin_price_reductions_collection(_membership = nil)
    PriceReduction.kept.order_by_name.map { |reduction| [ reduction.name, reduction.id ] }
  end

  def admin_price_reduction_choices(membership)
    selected_id = membership.price_reduction_choice_id
    membership.member&.member_cards&.load
    PriceReduction.kept.includes(:price_reduction_card).order_by_name.map { |reduction|
      issue = price_reduction_choice_issue(reduction, membership, selected_id)
      html = { data: price_reduction_placeholder_data(reduction) }
      html[:disabled] = true if issue
      [ price_reduction_choice_label(reduction, issue), reduction.id, html ]
    }
  end

  def price_reduction_placeholder_data(reduction)
    PriceReductionRule::FIELDS.index_with { |field|
      catalog_price_placeholder(reduction.public_send(field))
    }
  end

  def membership_price_reduction_selected(membership)
    return if membership.price_reduction_choice_id.blank?

    grant = membership.membership_price_reduction
    selected = grant&.price_reduction_id == membership.price_reduction_choice_id
    if grant && !grant.marked_for_destruction? && selected
      return grant.price_reduction
    end

    PriceReduction.kept.find_by(id: membership.price_reduction_choice_id)
  end

  def membership_price_reduction_hint(key, anchor)
    t("formtastic.hints.membership.price_reduction_#{key}_html",
      handbook: price_reduction_handbook_link(anchor),
      currency: Current.org.currency_code.upcase)
  end

  def membership_price_reduction_input(form, field, reduction, exclusive: false)
    grant = form.object
    data = {
      form_price_reduction_target: "ruleInput",
      form_price_reduction_placeholder: field.to_s.camelize(:lower),
      action: "input->form-price-reduction#refresh"
    }
    if exclusive
      data[:form_exclusive_target] = "input"
      data[:action] = [
        "input->form-exclusive#sync",
        "input->form-price-reduction#refresh"
      ].join(" ")
    end
    default = reduction&.public_send(field)
    current = catalog_price_form_value(grant.public_send(field), default)
    options = {
      label: PriceReduction.human_attribute_name(field),
      min: field == :percentage ? 0.01 : 0.05,
      step: field == :percentage ? 0.01 : 0.05,
      required: false,
      input_html: {
        value: current || "",
        placeholder: catalog_price_placeholder(default),
        data: data
      }
    }
    options[:max] = 100 if field == :percentage
    form.input(field, **options)
  end

  def price_reduction_percentage_label(percentage)
    "#{percentage.to_s.sub(/\.0+\z/, "")}%"
  end

  def price_reduction_cap_modes_collection
    PriceReduction::CAP_MODES.map { |mode|
      [ PriceReduction.human_attribute_name("cap_mode/#{mode}"), mode ]
    }
  end

  def price_reduction_handbook_hint(key, anchor)
    t("formtastic.hints.price_reduction.#{key}_html",
      handbook: price_reduction_handbook_link(anchor),
      currency: Current.org.currency_code.upcase)
  end

  def price_reduction_handbook_link(anchor)
    return "".html_safe unless Handbook.new("price_reductions", nil).filepath.exist?

    t("formtastic.hints.price_reduction.handbook_html",
      url: handbook_page_path("price_reductions", anchor: anchor))
  end

  def price_reduction_choice_label(reduction, issue)
    parts = [ reduction.name, reduction.rule_label ]
    if issue
      parts << t("price_reductions.choice.#{issue}", card: reduction.price_reduction_card.name)
    end
    parts.compact.join(", ")
  end

  def price_reduction_choice_issue(reduction, membership, selected_id)
    return if selected_id == reduction.id

    type = reduction.price_reduction_card
    return unless type

    card = membership.member&.member_card_for(type)
    on = membership.started_on || Date.current
    return :required if card.nil? || !card.complete?
    return :expired if type.require_expires_on? && card.expires_on && card.expires_on < on

    nil
  end

  # attrs present means a live form post: blank fields are the selected program's defaults.
  # Without attrs, use the stored grant so an unsaved override still previews.
  def price_reduction_preview_payload(membership, reduction, attrs = nil)
    return { text: "", error: "" } unless reduction

    grant = if attrs
      preview_price_reduction_grant(reduction, attrs)
    else
      preview_stored_price_reduction_grant(membership, reduction)
    end
    gross = membership&.price_before_reduction.to_d
    year = membership&.fy_year || Current.fy_year
    amount = preview_price_reduction_amount(membership, grant, gross)
    remaining = reduction.remaining_amount(
      reduction.fiscal_year_cap? ? year : nil,
      excluding: membership&.membership_price_reduction)
    warning = preview_price_reduction_warning(membership, reduction, amount, year)
    text = if remaining
      t("formtastic.hints.membership.price_reduction_remaining", remaining: cur(remaining))
    else
      ""
    end
    {
      text: text,
      error: price_reduction_refusal_message(warning)
    }
  end

  def price_reduction_field_error(membership, preview)
    posted = membership.errors.where(:price_reduction).map(&:message)
    return posted.first if posted.any?

    preview[:error].presence
  end

  def price_reduction_refusal_message(reason)
    key = {
      depot: :price_reduction_depot,
      card: :price_reduction_card,
      discarded: :price_reduction_discarded,
      cap: :price_reduction_exceeds_cap
    }[reason]
    return "" unless key

    t("errors.messages.#{key}")
  end

  def preview_stored_price_reduction_grant(membership, reduction)
    stored = membership&.membership_price_reduction
    source = stored if stored&.price_reduction_id == reduction.id && !stored.marked_for_destruction?
    source ||= reduction
    MembershipPriceReduction.new(
      price_reduction: reduction,
      percentage: source.percentage,
      fixed_amount: source.fixed_amount)
  end

  def preview_price_reduction_grant(reduction, attrs)
    grant = MembershipPriceReduction.new(price_reduction: reduction)
    percentage = attrs[:percentage].presence
    fixed_amount = attrs[:fixed_amount].presence
    if percentage || fixed_amount
      grant.percentage = percentage
      grant.fixed_amount = fixed_amount
    else
      grant.percentage = reduction.percentage
      grant.fixed_amount = reduction.fixed_amount
    end
    grant
  end

  def preview_price_reduction_amount(membership, grant, gross)
    return 0 if membership&.member&.salary_basket?

    grant.raw_amount(gross)
  end

  def preview_price_reduction_warning(membership, reduction, amount, year)
    return unless membership

    reduction.skip_reason(
      membership.price_before_reduction,
      depot: membership.depot,
      year: year,
      member: membership.member,
      on: membership.started_on || Date.current,
      excluding: membership.membership_price_reduction,
      amount: amount)
  end

  def admin_depots
    Depot.kept.order_by_name
  end

  def admin_depots_collection(options = nil)
    grouped_by_visibility(admin_depots, options)
  end

  def admin_depots_grouped_collection
    return unless DepotGroup.any?

    depots = admin_depots.includes(:group)
    grouped = depots.group_by(&:group_id)

    result = []
    DepotGroup.order_by_name.each do |group|
      items = grouped[group.id]
      next unless items&.any?
      result << [ group.name, items.map(&:id) ]
    end

    ungrouped = grouped[nil]
    if ungrouped&.any?
      result << [ I18n.t("delivery.ungrouped_depots"), ungrouped.map(&:id) ]
    end

    result.presence
  end

  def admin_basket_sizes
    BasketSize.kept.ordered
  end

  def admin_basket_sizes_collection(options = nil)
    grouped_by_visibility(admin_basket_sizes, options)
  end

  def admin_basket_complements
    BasketComplement.kept.ordered
  end

  def admin_basket_complements_collection(options = nil)
    grouped_by_visibility(admin_basket_complements, options)
  end

  def admin_delivery_cycles
    DeliveryCycle.kept.ordered
  end

  def admin_delivery_cycles_collection
    delivery_cycles_option_for_select(admin_delivery_cycles)
  end

  def admin_delivery_cycles_collection_by_visibility
    cycles = admin_delivery_cycles
    visible_cycles = cycles.visible.to_a
    hidden_cycles = cycles.to_a - visible_cycles

    if hidden_cycles.empty?
      delivery_cycles_option_for_select(cycles)
    else
      [
        [ t("active_admin.scopes.visible"), delivery_cycles_option_for_select(visible_cycles) ],
        [ t("active_admin.scopes.hidden"), delivery_cycles_option_for_select(hidden_cycles) ]
      ]
    end
  end

  def member_state_collection(exclude: [])
    (Member::STATES - exclude).map do |state|
      [ I18n.t("states.member.#{state}"), state ]
    end
  end

  def member_cities_collection
    Member.pluck(:city).uniq.map(&:presence).compact.sort
  end

  def activity_participation_form_activities_collection(participation = nil)
    collection = Activity.admin_form_collection(selected: participation&.activity)
    [
      [ t("active_admin.scopes.coming"), option_for_select(collection[:coming]) ],
      [ t("active_admin.scopes.past"), option_for_select(collection[:past]) ]
    ]
  end

  def grouped_by_date(relation, past: :last)
    if fy_year = params.dig(:q, :during_year)
      relation = relation.during_year(fy_year)
    end
    if past == :last
      [
        [ t("active_admin.scopes.coming"), option_for_select(relation.coming.order(:date)) ],
        [ t("active_admin.scopes.past"), option_for_select(relation.past.reorder(date: :desc)) ]
      ]
    else
      [
        [ t("active_admin.scopes.past"), option_for_select(relation.past.order(:date)) ],
        [ t("active_admin.scopes.coming"), option_for_select(relation.coming.order(:date)) ]
      ]
    end
  end

  def grouped_by_visibility(relation, options)
    all_records = relation.to_a
    visible_records, hidden_records = all_records.partition(&:visible?)

    if hidden_records.empty?
      option_for_select(all_records, options)
    else
      [
        [ t("active_admin.scopes.visible"), option_for_select(visible_records, options) ],
        [ t("active_admin.scopes.hidden"), option_for_select(hidden_records, options) ]
      ]
    end
  end

  private

  def delivery_cycles_option_for_select(cycles)
    cycles.map { |cycle|
      [
        "#{cycle.name} (#{t('helpers.deliveries_count', count: cycle.deliveries_count)})",
        cycle.id,
        { data: {
            price: catalog_price_placeholder(cycle.price),
            absences_included_annually: cycle.absences_included_annually
          } }
      ]
    }
  end

  def option_for_select(records, options = nil)
    records.map { |record|
      [ record.display_name, record.id, option_html_options(record, options&.call(record)) ].compact
    }
  end

  def option_html_options(record, extra = nil)
    html = extra ? extra.dup : {}
    if record.respond_to?(:price)
      data = (html[:data] || {}).dup
      data[:price] = catalog_price_placeholder(record.price)
      html[:data] = data
    end
    html.presence
  end
end
