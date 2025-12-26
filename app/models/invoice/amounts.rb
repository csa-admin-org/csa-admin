# frozen_string_literal: true

# Handles amount calculations for invoices.
# This includes setting amounts, applying percentages, VAT calculations,
# and balance tracking (paid, overpaid, missing amounts).
module Invoice::Amounts
  extend ActiveSupport::Concern

  included do
    scope :unpaid, -> { not_canceled.where("invoices.paid_amount < invoices.amount") }
    scope :overpaid, -> { not_canceled.where("invoices.amount > 0 AND invoices.paid_amount > invoices.amount") }
    scope :balance_eq, ->(amount) { where("(invoices.paid_amount - invoices.amount) = ?", amount.to_f) }
    scope :balance_gt, ->(amount) { where("(invoices.paid_amount - invoices.amount) > ?", amount.to_f) }
    scope :balance_lt, ->(amount) { where("(invoices.paid_amount - invoices.amount) < ?", amount.to_f) }

    validates :amount, presence: true
    validates :amount_percentage,
      numericality: {
        greater_than_or_equal_to: -100,
        less_than_or_equal_to: 200,
        allow_nil: true
      }
    validates :vat_rate, numericality: { greater_or_equal_to_than: 0, allow_nil: true }
    validates :vat_amount, presence: true, if: :vat_rate

    before_validation :set_amount, :set_vat_rate_and_amount, on: :create
  end

  def balance
    paid_amount - amount
  end

  def overpaid
    balance.positive? ? (paid_amount - amount) : 0
  end

  def missing_amount
    balance.negative? ? (amount - paid_amount) : 0
  end

  def overpaid?
    payments.not_ignored.sum(:amount) > amount
  end

  def payback?
    amount.negative?
  end

  def amount_with_vat
    memberships_amount || amount
  end

  def amount_without_vat
    return amount_with_vat unless vat_amount

    amount_with_vat - vat_amount
  end

  def send_overpaid_notification_to_admins!
    return if overpaid_notification_sent_at?
    return unless overpaid?

    Admin.notify!(:invoice_overpaid,
      member: member,
      invoice: self)
    touch(:overpaid_notification_sent_at)
  end

  def amount=(*_args)
    raise NoMethodError, "is set automaticaly."
  end

  def paid_amount=(*_args)
    raise NoMethodError, "is set automaticaly."
  end

  private

  def set_amount
    self[:amount] ||=
      if activity_participation_type? && activity_price && missing_activity_participations_count
        missing_activity_participations_count * activity_price
      else
        (memberships_amount || 0) + (annual_fee || 0)
      end
    apply_amount_percentage
  end

  def apply_amount_percentage
    if amount_percentage?
      self[:amount_before_percentage] = amount
      self[:amount] = (amount * (1 + amount_percentage / 100.0)).round_to_one_cent
    else
      self[:amount_before_percentage] = nil
    end
  end

  def set_vat_rate_and_amount
    if configured_vat_rate.presence&.positive?
      self[:vat_rate] = configured_vat_rate
      gross_amount = amount_with_vat
      net_amount = gross_amount / (1 + vat_rate / 100.0)
      self[:vat_amount] = gross_amount - net_amount.round_to_one_cent
    end
  end

  def configured_vat_rate
    case entity_type
    when "Membership"
      Current.org.vat_membership_rate
    when "ActivityParticipation"
      Current.org.vat_activity_rate
    when "Shop::Order"
      Current.org.vat_shop_rate
    when "Other", "NewMemberFee"
      vat_rate
    end
  end
end
