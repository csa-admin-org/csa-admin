# frozen_string_literal: true

module BasketOverridesHelper
  def display_basket_override(override)
    return unless override&.active?

    tag.div(class: "space-y-2") do
      concat override_header(override)
      concat override_diff_lines(override)
    end
  end

  private

  # Ordered list of diff keys to display with their label and audit attr mapping.
  # Keys whose parent also changed are skipped (e.g. depot_price when depot_id changed).
  OVERRIDE_DIFF_KEYS = [
    { key: "override_delivery_id", label: -> { Delivery.model_name.human } },
    { key: "basket_size_id",       label: -> { BasketSize.model_name.human }, audit_attr: "basket_size_id" },
    { key: "basket_size_price",    label: -> { Membership.human_attribute_name(:basket_size_price) }, audit_attr: "basket_size_price", skip_with: "basket_size_id" },
    { key: "depot_id",             label: -> { Depot.model_name.human }, audit_attr: "depot_id" },
    { key: "depot_price",          label: -> { Membership.human_attribute_name(:depot_price) }, audit_attr: "depot_price", skip_with: "depot_id" },
    { key: "quantity",             label: -> { Basket.human_attribute_name(:quantity) }, audit_attr: "quantity" },
    { key: "price_extra",          label: -> { Membership.human_attribute_name(:basket_price_extra) }, audit_attr: "basket_price_extra" },
    { key: "delivery_cycle_price", label: -> { Membership.human_attribute_name(:delivery_cycle_price) }, audit_attr: "delivery_cycle_price" },
    { key: "complements",          label: -> { BasketComplement.model_name.human(count: 2) }, audit_attr: "memberships_basket_complements", block: true }
  ].freeze

  def override_header(override)
    tag.div class: "mb-3" do
      concat tag.div(I18n.t("helpers.basket_override.title"), class: "font-semibold")
      concat tag.div(override_attribution_text(override), class: "text-xs text-gray-400")
    end
  end

  def override_attribution_text(override)
    date = l(override.updated_at, format: :short)
    if override.session&.member_id
      I18n.t("helpers.basket_override.by_member", date: date)
    elsif override.session&.admin_id
      I18n.t("helpers.basket_override.by_admin", name: override.actor.name, date: date)
    else
      I18n.t("helpers.basket_override.on_date", date: date)
    end
  end

  def override_diff_lines(override)
    diff = override.diff
    lines = []

    OVERRIDE_DIFF_KEYS.each do |spec|
      next unless diff.key?(spec[:key])
      next if spec[:skip_with] && diff.key?(spec[:skip_with])

      label = spec[:label].call
      lines << override_diff_line_tag(label, spec, diff[spec[:key]])
    end

    return tag.div if lines.empty?
    tag.div(safe_join(lines), class: "space-y-0.5")
  end

  def override_diff_line_tag(label, spec, value)
    if spec[:block]
      tag.div(class: "text-xs") do
        concat tag.div("#{label}:", class: "text-gray-400")
        concat override_formatted_value(spec, value)
      end
    else
      tag.div(class: "flex items-baseline gap-1.5 text-sm") do
        concat tag.span("#{label}:", class: "text-gray-400 shrink-0")
        concat override_formatted_value(spec, value)
      end
    end
  end

  def override_formatted_value(spec, value)
    if spec[:key] == "override_delivery_id"
      delivery = Delivery.find_by(id: value)
      return tag.span(delivery&.display_name(format: :number) || "–")
    end

    if spec[:audit_attr]
      display_audit_change(Membership, spec[:audit_attr], value)
    else
      tag.span(value.to_s)
    end
  end
end
