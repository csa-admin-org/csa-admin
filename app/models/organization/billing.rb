# frozen_string_literal: true

require "sepa_king"

module Organization::Billing
  extend ActiveSupport::Concern

  CURRENCIES = %w[CHF EUR]
  BILLING_YEAR_DIVISIONS = [ 1, 2, 3, 4, 12 ]
  BANK_CONNECTION_TYPES = %w[ebics bas bunq mock]

  included do
    include HasIBAN

    encrypts :bank_credentials

    validates :creditor_name, :creditor_street, :creditor_city, :creditor_zip, presence: true
    validates :bank_reference, format: { with: /\A\d+\z/, allow_blank: true }
    validates :iban, format: ->(org) { Billing.iban_format(org.country_code) }, allow_nil: true, if: :country_code?
    validates :fiscal_year_start_month,
      presence: true,
      inclusion: { in: 1..12 }
    validates :billing_year_divisions, presence: true
    validates :bank_connection_type, inclusion: { in: BANK_CONNECTION_TYPES }, allow_nil: true
    validates :bank_credentials, presence: true, if: :bank_connection_type?
    validates :recurring_billing_wday, inclusion: { in: 0..6 }, allow_nil: true
    validates :currency_code, presence: true, inclusion: { in: currency_codes }

    after_save :refresh_previsional_invoicing

    def billing_year_divisions=(divisions)
      super divisions.map(&:presence).compact.map(&:to_i) & BILLING_YEAR_DIVISIONS
    end

    def recurring_billing?
      !!recurring_billing_wday
    end

    def bank_connection?
      bank_connection_type?
    end

    def active_bank_connection
      BankConnection.active.first
    end

    def bank_connection
      case bank_connection_type
      when "ebics"
        Billing::EBICS.new(bank_credentials)
      when "bas"
        Billing::BAS.new(bank_credentials)
      when "bunq"
        Billing::Bunq.new(bank_credentials)
      when "mock"
        Billing::EBICSMock.new(bank_credentials)
      end
    end

    def send_invoice_overdue_notice?
      bank_connection? && MailTemplate.active_template("invoice_overdue_notice")
    end

    def fiscal_years
      min_year = [ Delivery.minimum(:date)&.year, Current.fy_year, Date.current.year ].compact.min
      max_year = [ Delivery.maximum(:date)&.year, Current.fy_year, Date.current.year ].compact.max
      (min_year..max_year).map { |year|
        Current.org.fiscal_year_for(year)
      }
    end

    def current_fiscal_year
      FiscalYear.current(start_month: fiscal_year_start_month)
    end

    def last_fiscal_year
      fiscal_year_for(current_fiscal_year.year - 1)
    end

    def next_fiscal_year
      fiscal_year_for(current_fiscal_year.year + 1)
    end

    def fiscal_year_for(date_or_year)
      return unless date_or_year

      FiscalYear.for(date_or_year, start_month: fiscal_year_start_month)
    end

    def fy_month_for(date)
      fiscal_year_for(date).fy_month(date)
    end

    def member_support?
      annual_fee? || shares?
    end

    def deliveries_count(year)
      @max_deliveries_counts ||=
        DeliveryCycle
          .pluck(:deliveries_counts)
          .reduce({}) { |h, i| h.merge(i) { |k, old, new| [ old, new ].flatten.max } }
      @max_deliveries_counts[year.to_s]
    end

    def swiss_qr?
      country_code == "CH"
    end

    def iban_type_name
      swiss_qr? ? "QR-IBAN" : "IBAN"
    end
  end

  class_methods do
    def currency_codes = CURRENCIES
    def billing_year_divisions = BILLING_YEAR_DIVISIONS
  end

  private

  def refresh_previsional_invoicing
    attrs = %w[
      billing_starts_after_first_delivery
      billing_ends_on_last_delivery_fy_month
      recurring_billing_wday
    ]
    return unless attrs.any? { |attr| previous_changes.key?(attr) }

    Billing::PrevisionalInvoicingRefreshJob.perform_later
  end
end
