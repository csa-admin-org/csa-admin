require 'rounding'
require 'bigdecimal'

class Invoice < ActiveRecord::Base
  include HasState
  include ActionView::Helpers::NumberHelper
  NoPdfError = Class.new(StandardError)

  attr_accessor :membership, :membership_amount_fraction

  has_states :not_sent, :open, :closed, :canceled

  belongs_to :member
  has_many :payments

  has_one_attached :pdf_file

  scope :current_year, -> { during_year(Time.zone.today.year) }
  scope :during_year, ->(year) {
    date = Date.new(year)
    where('date >= ? AND date <= ?', date.beginning_of_year, date.end_of_year)
  }
  scope :quarter, ->(n) { where('EXTRACT(QUARTER FROM date) = ?', n) }
  scope :support, -> { where.not(support_amount: nil) }
  scope :membership, -> { where.not(memberships_amount: nil) }
  scope :not_canceled, -> { where.not(state: CANCELED_STATE) }
  scope :cancelable, -> { where(state: [PENDING_STATE, OPEN_STATE]) }
  scope :overbalance, -> { where('balance > amount') }
  scope :with_overdue_notice, -> { open.where('overdue_notices_count > 0') }

  before_validation \
    :set_paid_memberships_amount,
    :set_remaining_memberships_amount,
    :set_memberships_amount,
    :set_amount

  validates :member, presence: true
  validates :date, presence: true, uniqueness: { scope: :member_id }
  validates :membership_amount_fraction, inclusion: { in: [1, 2, 3, 4] }
  validates :amount, numericality: { greater_than: 0 }
  validates :paid_memberships_amount,
    numericality: { greater_than_or_equal_to: 0 },
    allow_nil: true
  validates :memberships_amount,
    numericality: { greater_than: 0 },
    allow_nil: true
  validates :memberships_amount_description,
    presence: true,
    if: -> { memberships_amount? }
  validates :member_billing_interval,
    presence: true,
    inclusion: { in: Member::BILLING_INTERVALS }
  validate :validate_memberships_amount_for_current_year, on: :create

  def send!
    return unless can_send?
    raise NoPdfError unless pdf_file.attached?

    InvoiceMailer.new_invoice(self).deliver_now if can_send?
    touch(:sent_at)
    close_or_open!
  rescue => ex
    ExceptionNotifier.notify_exception(ex,
      data: { invoice_id: id, emails: member.emails, member_id: member_id })
  end

  def mark_as_sent!
    return if sent_at?
    raise NoPdfError unless pdf_file.attached?

    touch(:sent_at)
    close_or_open!
  end

  def cancel!
    invalid_transition(:close!) unless not_sent? || open?

    update!(
      canceled_at: Time.current,
      state: CANCELED_STATE)
  end

  def close_or_open!
    invalid_transition(:update_state!) if canceled?

    if balance >= amount
      update!(state: CLOSED_STATE)
    elsif sent_at?
      update!(state: OPEN_STATE)
    end
  end

  def balance_without_overbalance
    [balance, amount].min
  end

  def overbalance
    balance > amount ? (balance - amount).round_to_five_cents : 0
  end

  def missing_amount
    balance < amount ? (amount - balance).round_to_five_cents : 0
  end

  def membership_amount_fraction
    @membership_amount_fraction || 1 # bill for everything by default
  end

  def amount=(_)
    raise NoMethodError, 'is set automaticaly.'
  end

  def memberships_amount=(_)
    raise NoMethodError, 'is set automaticaly.'
  end

  def remaining_memberships_amount=(_)
    raise NoMethodError, 'is set automaticaly.'
  end

  def balance=(_)
    raise NoMethodError, 'is set automaticaly.'
  end

  def set_pdf
    invoice_pdf = InvoicePdf.new(self, nil)
    pdf_file.attach(
      io: StringIO.new(invoice_pdf.render),
      filename: "invoice-#{id}.pdf",
      content_type: 'application/pdf')
  end

  def can_cancel?
    not_sent? || open? || current_year?
  end

  def can_send?
    !sent_at? && member.emails?
  end

  def current_year?
    date.year == Date.current.year
  end

  private

  def validate_memberships_amount_for_current_year
    return unless membership
    paid_invoices = member.invoices.not_canceled.membership.during_year(date.year)
    if paid_invoices.sum(:memberships_amount) + memberships_amount > membership.price
      errors.add(:base, 'Somme de la facturation des abonnements trop grande')
    end
  end

  def set_paid_memberships_amount
    return unless membership
    paid_invoices = member.invoices.not_canceled.membership.during_year(date.year)
    self[:paid_memberships_amount] ||= paid_invoices.sum(:memberships_amount)
  end

  def set_remaining_memberships_amount
    return unless membership
    self[:remaining_memberships_amount] ||= membership.price - paid_memberships_amount
  end

  def set_memberships_amount
    return unless membership
    amount = remaining_memberships_amount / membership_amount_fraction.to_f
    self[:memberships_amount] ||= amount.round_to_five_cents
  end

  def set_amount
    self[:amount] = (memberships_amount || 0) + (support_amount || 0)
  end
end
