# frozen_string_literal: true

module Billing
  class PrevisionalInvoicing
    def self.month_label(month_key)
      I18n.l(Date.parse("#{month_key}-01"), format: :month_year)
    end

    def self.aggregate(memberships)
      memberships.each_with_object(Hash.new(0)) do |m, totals|
        m.previsional_invoicing_amounts.each do |month_key, amount|
          totals[month_key] += amount
        end
      end.sort.to_h
    end

    attr_reader :membership

    def initialize(membership)
      @membership = membership
    end

    def compute
      return {} unless projectable?

      next_billing_date = invoicer_next_date
      return {} unless next_billing_date

      periods = Billing::Periods.build(
        fiscal_year: membership.fiscal_year,
        billing_year_division: membership.billing_year_division)

      start_period = periods.find { |p| p.cover?(next_billing_date) }
      return {} unless start_period

      billed_dates = membership_invoice_dates
      last_month = Billing::Periods.last_fy_month(membership)
      fy = membership.fiscal_year

      unbilled = periods
        .drop_while { |p| p != start_period }
        .reject { |p| billed_dates.any? { |d| p.cover?(d) } }
        .select { |p| fy.fy_month(p.min) <= last_month }
      return {} if unbilled.empty?

      simulate_invoicing(unbilled, next_billing_date, last_month)
    end

    private

    def projectable?
      membership.price.present? &&
        membership.missing_invoices_amount.positive? &&
        !membership.member.salary_basket?
    end

    def invoicer_next_date
      Billing::Invoicer.new(membership.member, membership: membership).next_date(previsional: true)
    end

    def membership_invoice_dates
      membership.invoices.not_canceled
        .where.not(memberships_amount: [ nil, 0 ])
        .pluck(:date)
    end

    # First period uses next_billing_date (handles deferred billing),
    # subsequent periods use their start month.
    def simulate_invoicing(periods, next_billing_date, last_month)
      remaining = membership.missing_invoices_amount
      period_length = 12 / membership.billing_year_division
      fy = membership.fiscal_year
      result = {}

      periods.each_with_index do |period, i|
        break unless remaining.positive?

        fy_month = fy.fy_month(period.min)
        fraction = remaining_fraction(fy_month, last_month, period_length)
        amount = if i == periods.size - 1
          remaining # Last period absorbs any rounding remainder
        else
          (remaining / fraction.to_f).round_to_five_cents
        end

        month_key = if i == 0
          next_billing_date.strftime("%Y-%m")
        else
          period.min.strftime("%Y-%m")
        end

        result[month_key] = amount.to_f # Float for JSON serialization
        remaining -= amount
      end

      result
    end

    def remaining_fraction(fy_month, last_month, period_length)
      remaining_months = [ last_month - fy_month + 1, 1 ].max
      [ (remaining_months / period_length.to_f).ceil, 1 ].max
    end
  end
end
