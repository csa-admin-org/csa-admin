require 'rounding'
require 'bigdecimal'

class Invoice < ActiveRecord::Base
  include HasFiscalYearScopes
  include HasState
  include ActionView::Helpers::NumberHelper
  NoPDFError = Class.new(StandardError)

  OBJECT_TYPES = %w[Membership AnnualFee HalfdayParticipation]

  attr_writer :membership_amount_fraction, :send_email
  attr_accessor :comment

  has_states :not_sent, :open, :closed, :canceled

  belongs_to :member
  belongs_to :object, polymorphic: true, optional: true
  has_many :payments

  has_one_attached :pdf_file

  scope :annual_fee, -> { where.not(annual_fee: nil) }
  scope :membership, -> { where(object_type: 'Membership') }
  scope :not_canceled, -> { where.not(state: CANCELED_STATE) }
  scope :cancelable, -> { where(state: [PENDING_STATE, OPEN_STATE]) }
  scope :overbalance, -> { where('balance > amount') }
  scope :with_overdue_notice, -> { open.where('overdue_notices_count > 0') }
  scope :halfday_participation_type, -> { where(object_type: 'HalfdayParticipation') }

  with_options if: :membership_type?, on: :create do
    before_validation \
      :set_paid_memberships_amount,
      :set_remaining_memberships_amount,
      :set_memberships_amount,
      :set_memberships_vat_amount
  end
  before_validation :set_amount, on: :create

  validates :member, presence: true
  validates :date, presence: true
  validates :membership_amount_fraction, inclusion: { in: 1..12 }
  validates :object_type, inclusion: { in: OBJECT_TYPES }
  validates :amount, numericality: { greater_than: 0 }
  validates :paid_missing_halfday_works,
    numericality: { greater_than_or_equal_to: 1 },
    allow_blank: true
  validates :paid_memberships_amount,
    numericality: { greater_than_or_equal_to: 0 },
    allow_nil: true
  validates :memberships_amount,
    numericality: { greater_than: 0 },
    allow_nil: true
  validates :memberships_vat_amount,
    presence: true,
    if: -> { memberships_amount? && Current.acp.vat_membership_rate? }
  validates :memberships_amount_description,
    presence: true,
    if: -> { memberships_amount? }
  validate :validate_memberships_amount_for_current_year,
    on: :create,
    if: :membership_type?

  after_create :set_pdf, :send_email
  after_commit :update_membership_recognized_halfday_works!
  after_commit :update_member_invoices_balance!, on: :create

  def display_name
    "#{model_name.human} ##{id} (#{I18n.l date})"
  end

  def send!
    return unless can_send_email?
    raise NoPDFError unless pdf_file.attached?

    Email.deliver_now(:invoice_new, self) if can_send_email?
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

    transaction do
      update!(
        canceled_at: Time.current,
        state: CANCELED_STATE)
      update_member_invoices_balance!
    end
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

  def amount=(*args)
    if membership_type?
      raise NoMethodError, 'is set automaticaly.'
    else
      super
    end
  end

  def memberships_amount=(*_args)
    raise NoMethodError, 'is set automaticaly.'
  end

  def remaining_memberships_amount=(*_args)
    raise NoMethodError, 'is set automaticaly.'
  end

  def balance=(*_args)
    raise NoMethodError, 'is set automaticaly.'
  end

  def can_cancel?
    !canceled? && (not_sent? || open? || current_year?)
  end

  def can_send_email?
    !sent_at? && member.emails?
  end

  def membership_type?
    object_type == 'Membership'
  end

  def memberships_gross_amount
    memberships_amount
  end

  def memberships_net_amount
    (memberships_gross_amount - memberships_vat_amount) if memberships_gross_amount
  end

  private

  def validate_memberships_amount_for_current_year
    paid_invoices = member.invoices.not_canceled.membership.during_year(fy_year)
    if paid_invoices.sum(:memberships_amount) + memberships_amount > object.price
      errors.add(:base, 'Somme de la facturation des abonnements trop grande')
    end
  end

  def set_paid_memberships_amount
    paid_invoices = member.invoices.not_canceled.membership.during_year(fy_year)
    self[:paid_memberships_amount] ||= paid_invoices.sum(:memberships_amount)
  end

  def set_remaining_memberships_amount
    self[:remaining_memberships_amount] ||= object.price - paid_memberships_amount
  end

  def set_memberships_amount
    amount = remaining_memberships_amount / membership_amount_fraction.to_f
    self[:memberships_amount] ||= amount.round_to_five_cents
  end

  def set_amount
    self[:amount] ||= (memberships_amount || 0) + (annual_fee || 0)
  end

  def set_memberships_vat_amount
    if vat_rate = Current.acp.vat_membership_rate
      gross_amount = memberships_gross_amount
      net_amount = gross_amount / (1 + vat_rate / 100)
      self[:memberships_vat_amount] = gross_amount - net_amount.round(2)
    end
  end

  def set_pdf
    I18n.with_locale(member.language) do
      invoice_pdf = PDF::Invoice.new(self)
      pdf_file.attach(
        io: StringIO.new(invoice_pdf.render),
        filename: "invoice-#{id}.pdf",
        content_type: 'application/pdf')
    end
  end

  def update_member_invoices_balance!
    Payment.update_invoices_balance!(member_id)
  end

  def update_membership_recognized_halfday_works!
    if object_type == 'HalfdayParticipation'
      member.membership(fy_year)&.update_recognized_halfday_works!
    end
  end

  def send_email
    send! if @send_email
  end
end
