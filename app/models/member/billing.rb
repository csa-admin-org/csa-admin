# frozen_string_literal: true

module Member::Billing
  extend ActiveSupport::Concern

  included do
    validates :billing_name, :billing_street, :billing_city, :billing_zip,
      presence: true, if: :different_billing_info
    validate :billing_truemail

    scope :balance_amount_eq, ->(amount) { balance_amount_compare("=", amount) }
    scope :balance_amount_gt, ->(amount) { balance_amount_compare(">", amount) }
    scope :balance_amount_lt, ->(amount) { balance_amount_compare("<", amount) }
  end

  class_methods do
    def balance_amount_compare(operator, amount)
      raise ArgumentError, "unsupported operator" unless operator.in?(%w[= > <])

      # Payment's default date order is invalid inside this grouped subquery.
      payment_totals = Payment.not_ignored.unscope(:order)
        .group(:member_id)
        .select("member_id, SUM(amount) AS total")
      invoice_totals = Invoice.not_canceled
        .group(:member_id)
        .select("member_id, SUM(amount) AS total")

      joins("LEFT JOIN (#{payment_totals.to_sql}) payment_totals ON payment_totals.member_id = members.id")
        .joins("LEFT JOIN (#{invoice_totals.to_sql}) invoice_totals ON invoice_totals.member_id = members.id")
        .where(
          "COALESCE(payment_totals.total, 0) - COALESCE(invoice_totals.total, 0) #{operator} ?",
          amount.to_f)
    end
  end

  def first_billable_delivery
    if Current.org.trial_baskets? && trial_baskets_count.positive?
      baskets.trial.last&.delivery
    end || first_membership&.first_billable_delivery
  end

  def billable?
    support?
      || missing_shares_number.positive?
      || current_year_membership&.billable?
      || future_membership&.billable?
  end

  def billing_email=(email)
    super email&.strip.presence
  end

  def billing_emails
    return [] if discarded?

    if billing_email
      EmailSuppression.outbound.active.exists?(email: billing_email) ? [] : [ billing_email ]
    else
      active_emails
    end
  end

  def billing_emails?
    billing_emails.any?
  end

  def different_billing_info
    return @different_billing_info if defined?(@different_billing_info)

    @different_billing_info = [
      self[:billing_name],
      self[:billing_street],
      self[:billing_city],
      self[:billing_zip]
    ].all?(&:present?)
  end

  def different_billing_info=(bool)
    @different_billing_info = ActiveRecord::Type::Boolean.new.cast(bool)
    unless different_billing_info
      self.billing_name = nil
      self.billing_street = nil
      self.billing_city = nil
      self.billing_zip = nil
    end
  end

  def billing_info(attribute)
    send("billing_#{attribute}").presence || send(attribute)
  end

  def invoices_amount
    @invoices_amount ||= invoices.not_canceled.sum(:amount)
  end

  def payments_amount
    @payments_amount ||= payments.not_ignored.sum(:amount)
  end

  def balance_amount
    payments_amount - invoices_amount
  end

  def credit_amount
    [ balance_amount, 0 ].max
  end

  private

  def billing_truemail
    if billing_email && billing_email_changed? && !Truemail.valid?(billing_email)
      errors.add(:billing_email, :invalid)
    end
  end
end
