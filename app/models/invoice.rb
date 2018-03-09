require 'rounding'
require 'bigdecimal'

class Invoice < ActiveRecord::Base
  include HasFiscalYearScopes
  include HasState
  include ActionView::Helpers::NumberHelper
  NoPDFError = Class.new(StandardError)

  attr_accessor :membership, :membership_amount_fraction, :send_email

  has_states :not_sent, :open, :closed, :canceled

  belongs_to :member
  has_many :payments

  has_one_attached :pdf_file

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

  after_create :update_member_invoices_balance!
  after_create :set_pdf
  after_create :send_email

  validates :member, presence: true
  validates :date, presence: true
  validates :membership_amount_fraction, inclusion: { in: 1..12 }
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
  validate :validate_memberships_amount_for_current_year, on: :create

  def send!
    return unless can_send_email?
    raise NoPDFError unless pdf_file.attached?

    InvoiceMailer.new_invoice(self).deliver_now if can_send_email?
    touch(:sent_at)
    close_or_open!
  rescue => ex
    ExceptionNotifier.notify_exception(ex,
      data: { invoice_id: id, emails: member.emails, member_id: member_id })
  end

  def mark_as_sent!
    return if sent_at?
    raise NoPDFError unless pdf_file.attached?

    touch(:sent_at)
    close_or_open!
  end

  def cancel!
    invalid_transition(:close!) unless can_cancel?

    update!(
      canceled_at: Time.current,
      state: CANCELED_STATE)
  end

  def close_or_open!
    invalid_transition(:update_state!) if canceled?

    if missing_amount.zero?
      update!(state: CLOSED_STATE)
    elsif sent_at?
      update!(state: OPEN_STATE)
    else
      update!(state: NOT_SENT_STATE)
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

  def can_cancel?
    !canceled? && (not_sent? || open? || current_year?)
  end

  def can_send_email?
    !sent_at? && member.emails?
  end

  private

  def validate_memberships_amount_for_current_year
    return unless membership
    paid_invoices = member.invoices.not_canceled.membership.during_year(fy_year)
    if paid_invoices.sum(:memberships_amount) + memberships_amount > membership.price
      errors.add(:base, 'Somme de la facturation des abonnements trop grande')
    end
  end

  def set_paid_memberships_amount
    return unless membership
    paid_invoices = member.invoices.not_canceled.membership.during_year(fy_year)
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

  def set_pdf
    invoice_pdf = InvoicePDF.new(self)
    pdf_file.attach(
      io: StringIO.new(invoice_pdf.render),
      filename: "invoice-#{id}.pdf",
      content_type: 'application/pdf')
  end

  def update_member_invoices_balance!
    Payment.update_invoices_balance!(member_id)
  end

  def send_email
    send! if @send_email
  end
end
