# frozen_string_literal: true

module Query
  class OrganizationsIndex
    ALLOWED = %w[
      absence_extra_text_only
      absence_notice_period_in_days
      absences_billed
      absences_included_mode
      absences_included_reminder_weeks_before
      activity_availability_limit_in_days
      activity_i18n_scope
      activity_participation_deletion_deadline_in_days
      activity_participations_form_max
      activity_participations_form_min
      activity_participations_form_step
      activity_price
      allow_alternative_depots
      annual_fee
      annual_fee_member_form
      annual_fee_support_member_only
      basket_complements_member_order_mode
      basket_content_delivery_pdf_visible
      basket_content_member_display_product_url
      basket_content_member_display_quantity
      basket_content_member_visible
      basket_content_member_visible_hours_before
      basket_shift_deadline_in_weeks
      basket_shifts_annually
      basket_sizes_member_order_mode
      basket_update_limit_in_days
      bidding_round_basket_size_price_max_percentage
      bidding_round_basket_size_price_min_percentage
      billing_ends_on_last_delivery_fy_month
      billing_starts_after_first_delivery
      billing_year_divisions
      country_code
      currency_code
      delivery_cycles_member_order_mode
      delivery_pdf_member_info
      delivery_pdf_member_name_format
      depots_member_order_mode
      feature_flags
      features
      fiscal_year_start_month
      invoice_membership_summary_only
      languages
      local_currency_code
      local_currency_membership_annual_fee_only
      maps_style
      member_come_from_form_mode
      member_form_complement_quantities
      member_form_depot_map
      member_form_extra_text_only
      member_form_mode
      member_profession_form_mode
      membership_complements_update_allowed
      membership_depot_update_allowed
      membership_renewal_depot_update
      membership_renewed_attributes
      name
      new_member_fee
      recurring_billing_wday
      send_closed_invoice
      share_price
      shares_number
      shop_admin_only
      shop_delivery_open_delay_in_days
      shop_order_automatic_invoicing_delay_in_days
      trial_baskets_count
      url
      vat_activity_rate
      vat_membership_rate
      vat_shop_rate
    ].freeze
    DEFAULT_ATTRIBUTES = %w[
      name features absences_included_mode fiscal_year_start_month
      languages country_code
    ].freeze

    def self.run(token:, attributes: nil, filters: {}, tenants: nil)
      new(token: token, attributes: attributes, filters: filters, tenants: tenants).run
    end

    def initialize(token:, attributes: nil, filters: {}, tenants: nil)
      @token = token
      @tenants = tenants
      @attributes = parse_list(attributes)
      @attributes = DEFAULT_ATTRIBUTES if @attributes.empty?
      unknown = (@attributes - ALLOWED)
      raise Error, "unknown attribute #{unknown.join(", ")}" if unknown.any?

      @filters = stringify(filters)
      unknown_filters = @filters.keys - ALLOWED
      raise Error, "unknown filter #{unknown_filters.join(", ")}" if unknown_filters.any?
    end

    def run
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rows = []
      Walk.each(token: @token, tenants: @tenants) do
        org = Organization.first
        next unless org
        next unless matches?(org)

        rows << row_for(org)
      end
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)

      {
        organizations: rows,
        meta: {
          row_count: rows.length,
          query_time_ms: elapsed_ms
        }
      }
    end

    private

    def matches?(org)
      @filters.all? { |name, value| value_matches?(read(org, name), value) }
    end

    def row_for(org)
      @attributes.each_with_object("tenant" => Tenant.current) { |name, row|
        row[name] = serialize(read(org, name))
      }
    end

    def read(org, name)
      org.public_send(name)
    end

    def value_matches?(stored, wanted)
      if stored.is_a?(Array)
        stored.map(&:to_s).include?(wanted.to_s)
      elsif stored.is_a?(Numeric)
        BigDecimal(stored.to_s) == BigDecimal(wanted.to_s)
      else
        serialize(stored).to_s == wanted.to_s
      end
    rescue ArgumentError
      false
    end

    def serialize(value)
      case value
      when Array then value.map { |item| item.is_a?(Symbol) ? item.to_s : item }
      when BigDecimal then number_string(value)
      else value
      end
    end

    def number_string(value)
      text = value.to_s("F")
      text.sub(/\.0+\z/, "").sub(/(\.[0-9]*?)0+\z/, "\1")
    end

    def parse_list(value)
      Array(value).flat_map { |item| item.to_s.split(",") }.map(&:strip).compact_blank
    end

    def stringify(filters)
      filters.to_h.transform_keys(&:to_s).except(
        "controller", "action", "format", "subdomain",
        "attributes", "tenant", "tenants")
    end
  end
end
