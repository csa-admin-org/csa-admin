# frozen_string_literal: true

# Helper methods for rendering audit trail changes in the admin interface.
#
# This helper provides formatting for various attribute types when displaying
# audit changes. It automatically handles common patterns like belongs_to
# associations, prices, dates, booleans, and translated hashes.
#
# == Adding Support for New Attributes
#
# When auditing new attributes, you may need to register them here for proper
# display formatting:
#
# 1. **Price attributes**: Add to PRICE_ATTRIBUTES to display with currency formatting
# 2. **Belongs-to associations**: Add to BELONGS_TO_ATTRIBUTES with the attribute name
#    and model class to render as links
# 3. **Date attributes**: Add to DATE_ATTRIBUTES for localized date formatting
# 4. **Translated hashes**: Add attribute name to TRANSLATED_HASH_ATTRIBUTES
# 5. **Special cases**: Add a new when clause in display_audit_change
#
# Unregistered attributes fall through to display_default_change which handles
# booleans and renders other values as-is.
#
module AuditsHelper
  include NumbersHelper
  include DeliveryCyclesHelper

  # Attributes that should be displayed with currency formatting.
  # Add new price/money attributes here.
  PRICE_ATTRIBUTES = %w[
    price
    basket_size_price
    basket_price_extra
    depot_price
    delivery_cycle_price
    baskets_annual_price_change
    basket_complements_annual_price_change
    activity_participations_annual_price_change
    annual_fee
    renewal_annual_fee
  ].freeze

  # Belongs-to association attributes mapped to their model classes.
  # These will be rendered as links to the associated record.
  # Add new belongs_to attributes here: "attribute_name" => ModelClass
  BELONGS_TO_ATTRIBUTES = {
    "member_id" => Member,
    "basket_size_id" => BasketSize,
    "depot_id" => Depot,
    "shop_depot_id" => Depot,
    "delivery_cycle_id" => DeliveryCycle
  }.freeze

  # Attributes that should be displayed as formatted dates.
  # Add new date attributes here.
  DATE_ATTRIBUTES = %w[
    date
    started_on
    ended_on
    renewed_at
    renewal_opened_at
    sepa_mandate_signed_on
  ].freeze

  # Attributes that contain translated hashes (locale => value).
  TRANSLATED_HASH_ATTRIBUTES = %w[
    names
    public_names
    invoice_names
    form_details
  ].freeze

  # Attributes that should use compact diff rendering (showing only changes).
  # These are list-type attributes where showing full before/after is repetitive.
  DIFF_ATTRIBUTES = %w[
    depot_ids
    shop_open_for_depot_ids
    wdays
    periods
  ].freeze

  # Determines if an audit change should be displayed.
  # Returns false if both before and after values are effectively empty.
  def should_display_audit_change?(attr, before_value, after_value)
    attr = attr.to_s

    # For translated hashes, check if both are empty
    if attr.in?(TRANSLATED_HASH_ATTRIBUTES)
      before_empty = before_value.blank? || before_value.values.none?(&:present?)
      after_empty = after_value.blank? || after_value.values.none?(&:present?)
      return false if before_empty && after_empty
    end

    # For arrays (like wdays, memberships_basket_complements), check if both are empty
    if before_value.is_a?(Array) && after_value.is_a?(Array)
      return false if before_value.blank? && after_value.blank?
    end

    true
  end

  # Renders a compact diff for list-type attributes, showing only what changed.
  # Returns nil if this attribute doesn't use diff rendering.
  #
  # @param attr [String] The attribute name
  # @param before_value [Array] The value before the change
  # @param after_value [Array] The value after the change
  # @return [String, nil] HTML-safe diff output, or nil if not a diff attribute
  def render_audit_diff(attr, before_value, after_value)
    attr = attr.to_s
    return nil unless attr.in?(DIFF_ATTRIBUTES)

    before_value ||= []
    after_value ||= []

    case attr
    when "depot_ids", "shop_open_for_depot_ids"
      render_depot_ids_diff(before_value, after_value)
    when "wdays"
      render_wdays_diff(before_value, after_value)
    when "periods"
      render_periods_diff(before_value, after_value)
    end
  end

  # Unified method for displaying audit changes for any model.
  #
  # @param model_class [Class] The model class for i18n lookups (e.g., Member, Membership)
  # @param attr [String, Symbol] The attribute name being displayed
  # @param change [Object] The before or after value of the change
  # @param opts [Hash] Additional options passed to content_tag
  # @return [String] HTML-safe string representing the change value
  def display_audit_change(model_class, attr, change, **opts)
    attr = attr.to_s

    # Handle nil/blank values first for most types
    # Translated hashes, periods, complements, depot_ids, and booleans need special handling
    unless attr.in?(TRANSLATED_HASH_ATTRIBUTES) || attr.in?(%w[periods memberships_basket_complements depot_ids shop_open_for_depot_ids])
      # Use nil? check for booleans since false.blank? returns true
      return display_empty_value if change.nil? || (change.respond_to?(:blank?) && change != false && change.blank?)
    end

    case attr
    when "state"
      display_state_change(model_class, change)
    when "phones"
      display_phones_change(change)
    when "country_code"
      display_country_change(change)
    when "memberships_basket_complements"
      display_basket_complements_change(change)
    when "depot_ids", "shop_open_for_depot_ids"
      display_depot_ids_change(change)
    when "periods"
      display_periods_list(change)
    when "basket_size_price_percentage"
      display_percentage_change(change, **opts)
    when "billing_year_division"
      content_tag(:span, t("billing.year_division.x#{change}"))
    when "week_numbers"
      content_tag(:span, t("delivery_cycle.week_numbers.#{change}"))
    when "wdays"
      display_wdays_change(change)
    when *TRANSLATED_HASH_ATTRIBUTES
      display_translated_hash_change(change)
    when *BELONGS_TO_ATTRIBUTES.keys
      display_belongs_to_change(BELONGS_TO_ATTRIBUTES[attr], change)
    when *DATE_ATTRIBUTES
      display_date_change(change, **opts)
    when *PRICE_ATTRIBUTES
      display_price_change(change, **opts)
    else
      display_default_change(change, **opts)
    end
  end

  private

  def display_empty_value
    content_tag(:span, t("active_admin.empty"), class: "attributes-table-empty-value text-sm!")
  end

  def display_state_change(model_class, change)
    i18n_key = model_class.model_name.singular
    content_tag(:span, t("states.#{i18n_key}.#{change}"), class: "status-tag", data: { status: change })
  end

  def display_belongs_to_change(klass, id)
    if record = klass.find_by(id: id)
      auto_link record
    else
      content_tag(:span, t("active_admin.unknown"), class: "attributes-table-empty-value text-sm!")
    end
  end

  def display_date_change(change, **opts)
    content_tag(:span, l(change.to_date, format: :medium), **opts)
  end

  def display_price_change(change, **opts)
    content_tag(:span, cur(change), **opts)
  end

  def display_boolean_change(change)
    content_tag(:span, t("active_admin.status_tag.#{change}"), class: "status-tag", data: { status: change ? "yes" : "no" })
  end

  def display_country_change(country_code)
    country = ISO3166::Country[country_code]
    content_tag(:span, country&.translations&.dig(I18n.locale.to_s) || country&.common_name || country_code)
  end

  def display_phones_change(phones)
    formatted = phones.split(",").map { |phone| format_phone_for_display(phone.strip) }.join(", ")
    content_tag(:span, formatted)
  end

  def format_phone_for_display(phone)
    format = if PhonyRails.country_from_number(phone) == Current.org.country_code
      :national
    else
      :international
    end
    phone.phony_formatted(format: format)
  end

  def display_default_change(change, **opts)
    case change
    when true, false
      display_boolean_change(change)
    else
      content_tag(:span, change, **opts)
    end
  end

  def display_percentage_change(change, **opts)
    content_tag(:span, number_to_percentage(change || 100, precision: 0), **opts)
  end

  def display_depot_ids_change(depot_ids)
    return display_empty_value if depot_ids.blank?

    depots = Depot.where(id: depot_ids).order(:position)
    return display_empty_value if depots.none?

    content_tag(:ul, class: "list-disc list-inside text-sm") do
      safe_join(depots.map { |depot| content_tag(:li, depot.name) })
    end
  end

  def display_basket_complements_change(complements)
    return display_empty_value if complements.blank?

    content_tag(:ul, class: "list-disc list-inside text-sm") do
      safe_join(complements.filter_map { |comp|
        complement = BasketComplement.find_by(id: comp["basket_complement_id"])
        next unless complement

        parts = [ "#{comp["quantity"]}x #{complement.name}" ]
        parts << cur(comp["price"]) if comp["price"]
        if comp["delivery_cycle_id"]
          cycle = DeliveryCycle.find_by(id: comp["delivery_cycle_id"])
          parts << "(#{cycle.name})" if cycle
        end

        content_tag(:li, parts.join(" "))
      })
    end
  end

  # Displays a translated hash (locale => value).
  # - If only one locale has a value, show just the value (no locale prefix)
  # - If multiple locales have values, show as a list with locale prefixes
  # - If no locales have values, show EMPTY
  def display_translated_hash_change(hash)
    # Handle nil or completely empty hash
    return display_empty_value if hash.blank?

    # Filter to only locales with non-blank values
    present_values = hash.select { |_, value| value.present? }

    # If no locales have values, show empty
    return display_empty_value if present_values.empty?

    # If only one locale has a value, show it simply without locale prefix
    if present_values.size == 1
      return content_tag(:span, present_values.values.first)
    end

    # Multiple locales: show as list with locale prefixes
    content_tag(:ul, class: "list-disc list-inside text-sm") do
      safe_join(present_values.map { |locale, value|
        content_tag(:li, "#{locale.upcase}: #{value}")
      })
    end
  end

  # Displays weekdays as localized abbreviated day names
  def display_wdays_change(wdays)
    return display_empty_value if wdays.blank?

    day_names = wdays.map { |d| t("date.abbr_day_names")[d].capitalize }
    content_tag(:span, day_names.join(", "))
  end

  # Renders a simple list of periods (used for before or after display)
  def display_periods_list(periods)
    return display_empty_value if periods.blank?

    content_tag(:ul, class: "list-disc list-inside text-sm") do
      safe_join(periods.map { |period| content_tag(:li, format_period(period)) })
    end
  end

  # Renders a compact diff for depot IDs, showing only added/removed depots
  def render_depot_ids_diff(before_ids, after_ids)
    removed_ids = before_ids - after_ids
    added_ids = after_ids - before_ids

    removed_depots = Depot.where(id: removed_ids).order(:position)
    added_depots = Depot.where(id: added_ids).order(:position)

    render_list_diff(
      removed: removed_depots.map(&:name),
      added: added_depots.map(&:name)
    )
  end

  # Renders a compact diff for weekdays, showing only added/removed days
  def render_wdays_diff(before_wdays, after_wdays)
    removed = (before_wdays - after_wdays).map { |d| t("date.day_names")[d].capitalize }
    added = (after_wdays - before_wdays).map { |d| t("date.day_names")[d].capitalize }

    render_list_diff(removed: removed, added: added)
  end

  # Renders a compact diff for periods, showing only changed periods with left → right pattern
  # Uses period ID for matching (new audits) or falls back to range matching (old audits)
  def render_periods_diff(before_periods, after_periods)
    # Use ID if available (new audits), otherwise fall back to range key (old audits)
    key_method = before_periods.any? { |p| p["id"] } ? :period_id_key : :period_range_key

    before_by_key = before_periods.index_by { |p| send(key_method, p) }
    after_by_key = after_periods.index_by { |p| send(key_method, p) }

    all_keys = (before_by_key.keys | after_by_key.keys).sort_by(&:to_s)

    changes = all_keys.filter_map do |key|
      before_period = before_by_key[key]
      after_period = after_by_key[key]

      # Skip unchanged periods
      next if before_period == after_period

      {
        before: before_period ? format_period(before_period) : nil,
        after: after_period ? format_period(after_period) : nil
      }
    end

    return nil if changes.empty?

    content_tag(:ul, class: "space-y-1 text-sm") do
      safe_join(changes.map do |change|
        content_tag(:li, class: "flex items-center gap-2") do
          before_content = change[:before] || t("active_admin.empty")
          after_content = change[:after] || t("active_admin.empty")

          concat(content_tag(:span, before_content, class: "text-gray-500 dark:text-gray-400"))
          concat(content_tag(:span, "→", class: "text-gray-400 dark:text-gray-500"))
          concat(content_tag(:span, after_content))
        end
      end)
    end
  end

  def period_id_key(period)
    period["id"]
  end

  def period_range_key(period)
    [ period["from_fy_month"].to_i, period["to_fy_month"].to_i ]
  end

  # Generic helper to render a compact list diff with consistent styling
  # Shows + for added items and − for removed items
  def render_list_diff(removed: [], added: [])
    content_tag(:ul, class: "space-y-1 text-sm") do
      items = []

      # Removed items (grayed, with minus)
      removed.each do |item|
        items << content_tag(:li, class: "text-gray-500 dark:text-gray-400") do
          "− #{item}"
        end
      end

      # Added items (with plus)
      added.each do |item|
        items << content_tag(:li) { "+ #{item}" }
      end

      safe_join(items)
    end
  end

  def format_period(period)
    from_month = fy_month_name(period["from_fy_month"])
    to_month = fy_month_name(period["to_fy_month"])

    months_range = if period["from_fy_month"] == period["to_fy_month"]
      from_month
    else
      "#{from_month} – #{to_month}"
    end

    results = t("delivery_cycle.results.#{period["results"]}")
    [ months_range, results ].join(", ")
  end
end
