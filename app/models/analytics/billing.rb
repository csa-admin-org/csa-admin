# frozen_string_literal: true

class Analytics::Billing
  include Analytics::Series

  def self.available? = true
  def self.icon = "banknotes"

  Year = Data.define(
    :fiscal_year,
    :count,
    :amount,
    :memberships_amount,
    :annual_fee_amount,
    :amounts_by_type,
    :paid_amount,
    :overdue_notices_count,
    :overdue_rate,
    :time_to_pay_median,
    :time_to_pay_p90,
    :time_to_pay_count
  ) do
    include Analytics::Year
  end

  ENTITY_TYPES = %w[
    Share
    Shop::Order
    ActivityParticipation
    NewMemberFee
    Other
  ].freeze

  def types
    @types ||= begin
      used = series.flat_map { |year|
        year.amounts_by_type.select { |_type, amount| amount.positive? }.keys
      }.uniq
      ENTITY_TYPES.select { |type| used.include?(type) }
    end
  end

  def payments?
    series.any? { |year| year.amount.positive? || year.paid_amount.positive? }
  end

  def overdue_notices?
    series.any? { |year| year.overdue_notices_count.positive? }
  end

  def time_to_pay?
    series.any? { |year| year.time_to_pay_count.positive? }
  end

  def charts
    [].tap do |panels|
      panels << chart.stacked_bar(
        "invoice-amounts", I18n.t("analytics.charts.invoice_amounts"), "receipt-text",
        invoice_amount_datasets,
        currency: true)
      if payments?
        panels << chart.grouped_bar(
          "payments", I18n.t("analytics.charts.payments"), "banknotes",
          [
            [ I18n.t("analytics.metrics.invoiced"), series.map { |year| decimal_or_nil(year.amount) } ],
            [ I18n.t("billing.scope.paid"), series.map { |year| decimal_or_nil(year.paid_amount) } ]
          ],
          currency: true)
      end
      if overdue_notices?
        panels << chart.rate_line(
          "overdue-notices", I18n.t("analytics.charts.overdue_notices"), "mail-warning",
          [ [ I18n.t("analytics.metrics.overdue_rate"), series.map { |year| decimal_or_nil(year.overdue_rate) } ] ])
      end
      if time_to_pay?
        panels << chart.grouped_bar(
          "time-to-pay", I18n.t("analytics.charts.time_to_pay"), "clock",
          [
            [ I18n.t("analytics.metrics.time_to_pay_median"), series.map { |year| decimal_or_nil(year.time_to_pay_median) } ],
            [ I18n.t("analytics.metrics.time_to_pay_p90"), series.map { |year| decimal_or_nil(year.time_to_pay_p90) } ]
          ])
      end
    end
  end

  def headlines
    [
      headline(currency_title(I18n.t("analytics.metrics.invoiced")), series.map { |year| format_currency(year.amount) }),
      headline(currency_title(I18n.t("billing.scope.paid")), series.map { |year| format_currency(year.paid_amount) }),
      headline(I18n.t("analytics.metrics.time_to_pay_median"), series.map { |year| format_days(year.time_to_pay_median) }),
      headline(I18n.t("analytics.metrics.time_to_pay_p90"), series.map { |year| format_days(year.time_to_pay_p90) })
    ]
  end

  private

  def invoice_amount_datasets
    [
      [ Membership.model_name.human(count: 2), series.map { |year| decimal_or_nil(year.memberships_amount) } ],
      [ I18n.t("billing.annual_fees"), series.map { |year| decimal_or_nil(year.annual_fee_amount) } ],
      *types.map { |type|
        [ invoice_type_label(type), series.map { |year| decimal_or_nil(year.amounts_by_type[type]) } ]
      }
    ].select { |_label, amounts| amounts.any? { |amount| amount&.positive? } }
  end

  def invoice_type_label(type)
    case type
    when "Share" then I18n.t("billing.shares")
    when "Shop::Order" then I18n.t("shop.title_orders", count: 2)
    when "ActivityParticipation" then I18n.t("activities.#{Current.org.activity_i18n_scope}.other")
    when "NewMemberFee" then I18n.t("invoices.entity_type.new_member_fee")
    when "Other" then I18n.t("billing.other")
    else type
    end
  end

  InvoiceRow = Data.define(
    :date,
    :entity_type,
    :amount,
    :memberships_amount,
    :annual_fee,
    :overdue_notices_count)

  PaymentRow = Data.define(:date, :amount)

  def rows
    @rows ||= Invoice.not_canceled.pluck(
      :date,
      :entity_type,
      :amount,
      :memberships_amount,
      :annual_fee,
      :overdue_notices_count
    ).map { |values| InvoiceRow.new(*values) }
  end

  # Cash view: payments are grouped by payment date, so a late payment
  # counts in the year it was received, not the year it was invoiced.
  def payment_rows
    @payment_rows ||= Payment.not_ignored.pluck(:date, :amount)
      .map { |values| PaymentRow.new(*values) }
  end

  def time_to_pay_rows
    @time_to_pay_rows ||= Invoice
      .not_canceled
      .where("invoices.amount > 0")
      .joins("INNER JOIN payments ON payments.invoice_id = invoices.id AND payments.ignored_at IS NULL")
      .group("invoices.id")
      .pluck(:date, :sent_at, Arel.sql("MIN(payments.date)"))
      .map { |date, sent_at, paid_on|
        # Convert sent_at (stored in UTC) to a local date in Ruby; SQLite's
        # date() would shift late-evening timestamps to the previous day.
        paid_on = Date.parse(paid_on) if paid_on.is_a?(String)
        [ date, (paid_on - (sent_at&.to_date || date)).to_i ]
      }
  end

  def rows_by_year
    @rows_by_year ||= group_by_year(rows)
  end

  def payment_rows_by_year
    @payment_rows_by_year ||= group_by_year(payment_rows)
  end

  def time_to_pay_rows_by_year
    @time_to_pay_rows_by_year ||= time_to_pay_rows.group_by { |date, _days| Analytics.year_for(date) }
  end

  def payments_during(fiscal_year)
    payment_rows_by_year[fiscal_year.year] || []
  end

  def build_year(fiscal_year)
    invoices = during(fiscal_year)
    days = time_to_pay_days(fiscal_year)
    overdue_notices_count = invoices.count { |row| row.overdue_notices_count.to_i.positive? }

    Year.new(
      fiscal_year: fiscal_year,
      count: invoices.size,
      amount: invoices.sum { |row| row.amount.to_d },
      memberships_amount: invoices.sum { |row| row.memberships_amount.to_d },
      annual_fee_amount: invoices.sum { |row| row.annual_fee.to_d },
      amounts_by_type: amounts_by_type_for(invoices),
      paid_amount: payments_during(fiscal_year).sum { |row| row.amount.to_d },
      overdue_notices_count: overdue_notices_count,
      overdue_rate: invoices.empty? ? nil : (overdue_notices_count * 100.0 / invoices.size),
      time_to_pay_median: Analytics.percentile(days, 50),
      time_to_pay_p90: Analytics.percentile(days, 90),
      time_to_pay_count: days.size)
  end

  def amounts_by_type_for(invoices)
    ENTITY_TYPES.index_with { |type|
      invoices
        .select { |row| row.entity_type == type }
        .sum { |row| row.amount.to_d }
    }
  end

  def time_to_pay_days(fiscal_year)
    (time_to_pay_rows_by_year[fiscal_year.year] || [])
      .map { |_date, days| [ days.to_i, 0 ].max }
  end
end
