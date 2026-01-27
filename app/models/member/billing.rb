# frozen_string_literal: true

# Handles billing-related logic for members.
# This includes billing emails, billing info, balance calculations,
# and SEPA direct debit configuration.
module Member::Billing
  extend ActiveSupport::Concern

  included do
    validates :billing_name, :billing_street, :billing_city, :billing_zip,
      presence: true, if: :different_billing_info
    validate :billing_truemail
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

  def sepa?
    iban? && sepa_mandate_id? && sepa_mandate_signed_on?
  end

  def sepa_metadata
    return {} unless sepa?

    {
      name: billing_info(:name),
      iban: iban,
      mandate_id: sepa_mandate_id,
      mandate_signed_on: sepa_mandate_signed_on
    }
  end

  private

  def billing_truemail
    if billing_email && billing_email_changed? && !Truemail.valid?(billing_email)
      errors.add(:billing_email, :invalid)
    end
  end
end
