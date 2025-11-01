# frozen_string_literal: true

require "sepa_king"

module Organization::Billing
  extend ActiveSupport::Concern

  CURRENCIES = %w[CHF EUR]
  BILLING_YEAR_DIVISIONS = [ 1, 2, 3, 4, 12 ]
  BANK_CONNECTION_TYPES = %w[ebics bas mock]

  included do
    include HasIBAN

    validates :creditor_name, :creditor_address, :creditor_city, :creditor_zip, presence: true
    validates :bank_reference, format: { with: /\A\d+\z/, allow_blank: true }
    validates :iban, format: ->(org) { Billing.iban_format(org.country_code) }, allow_nil: true, if: :country_code?
    validates :fiscal_year_start_month,
      presence: true,
      inclusion: { in: 1..12 }
    validates_with SEPA::CreditorIdentifierValidator, field_name: :sepa_creditor_identifier, if: :sepa_creditor_identifier?
    validates :billing_year_divisions, presence: true
    validates :bank_connection_type, inclusion: { in: BANK_CONNECTION_TYPES }, allow_nil: true
    validates :bank_credentials, presence: true, if: :bank_connection_type?
    validates :annual_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :annual_fee_member_form, absence: true, unless: :annual_fee?
    validates :share_price, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
    validates :share_price, presence: true, if: :shares_number?
    validates :shares_number, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
    validates :shares_number, presence: true, if: :share_price?
    validates :vat_membership_rate, numericality: { greater_or_equal_to_than: 0, allow_nil: true }
    validates :vat_activity_rate, numericality: { greater_or_equal_to_than: 0, allow_nil: true }
    validates :vat_number, presence: true, if: -> {
      vat_membership_rate&.positive? || vat_activity_rate&.positive? || vat_shop_rate&.positive?
    }
    validates :recurring_billing_wday, inclusion: { in: 0..6 }, allow_nil: true
    validates :currency_code, presence: true, inclusion: { in: CURRENCIES }

    after_save :apply_annual_fee_change

    def billing_year_divisions=(divisions)
      super divisions.map(&:presence).compact.map(&:to_i) & BILLING_YEAR_DIVISIONS
    end

    def recurring_billing?
      !!recurring_billing_wday
    end

    def bank_connection?
      bank_connection_type?
    end

    def bank_connection
      case bank_connection_type
      when "ebics"
        Billing::EBICS.new(bank_credentials)
      when "bas"
        Billing::BAS.new(bank_credentials)
      when "mock"
        Billing::EBICSMock.new(bank_credentials)
      end
    end

    def send_invoice_overdue_notice?
      bank_connection? && MailTemplate.active_template("invoice_overdue_notice")
    end

    def fiscal_years
      min_year = Delivery.minimum(:date)&.year || Date.current.year
      max_year = Delivery.maximum(:date)&.year || Date.current.year
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
      fiscal_year_for(date).month(date)
    end

    def member_support?
      annual_fee? || share?
    end

    def annual_fee?
      annual_fee && annual_fee >= 0
    end

    def share?
      share_price&.positive?
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

    def sepa?
      country_code.in? %w[DE NL]
    end
  end

  class_methods do
    def currencies = CURRENCIES
    def billing_year_divisions = BILLING_YEAR_DIVISIONS
  end

  private

  def apply_annual_fee_change
    return unless annual_fee_previously_changed?

    Member
      .where(annual_fee: annual_fee_previously_was)
      .update_all(annual_fee: annual_fee)
  end
end
