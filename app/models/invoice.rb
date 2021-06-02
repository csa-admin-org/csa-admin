require 'rounding'
require 'bigdecimal'

class Invoice < ActiveRecord::Base
  include HasFiscalYearScopes
  include HasState
  include ActionView::Helpers::NumberHelper
  UnprocessedError = Class.new(StandardError)

  attr_writer :membership_amount_fraction, :send_email
  attr_reader :paid_missing_activity_participations_amount
  attr_accessor :comment

  has_states :processing, :not_sent, :open, :closed, :canceled

  belongs_to :member
  belongs_to :object, polymorphic: true, optional: true, touch: true
  has_many :items, class_name: 'InvoiceItem', dependent: :destroy
  has_many :payments, dependent: :destroy

  accepts_nested_attributes_for :items

  has_one_attached :pdf_file

  scope :annual_fee, -> { where.not(annual_fee: nil) }
  scope :membership, -> { where(object_type: 'Membership') }
  scope :acp_share, -> { where(object_type: 'ACPShare') }
  scope :not_processing, -> { where.not(state: PROCESSING_STATE) }
  scope :not_canceled, -> { where.not(state: CANCELED_STATE) }
  scope :sent, -> { where.not(sent_at: nil) }
  scope :all_without_canceled, -> { not_processing.not_canceled }
  scope :history, -> { not_processing.where.not(state: [NOT_SENT_STATE, OPEN_STATE]) }
  scope :unpaid, -> { not_canceled.where('paid_amount < amount') }
  scope :overpaid, -> { not_canceled.where('amount > 0 AND paid_amount > amount') }
  scope :balance_equals, ->(amount) { where('(paid_amount - amount) = ?', amount) }
  scope :balance_greater_than, ->(amount) { where('(paid_amount - amount) > ?', amount) }
  scope :balance_less_than, ->(amount) { where('(paid_amount - amount) < ?', amount) }
  scope :with_overdue_notice, -> { unpaid.where('overdue_notices_count > 0') }
  scope :group_buying_order_type, -> { where(object_type: 'GroupBuying::Order') }
  scope :activity_participation_type, -> { where(object_type: 'ActivityParticipation') }
  scope :other_type, -> { where(object_type: 'Other') }

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
  validates :object_type, inclusion: { in: proc { Invoice.object_types } }
  validates :amount, numericality: { other_than: 0 }
  validates :paid_missing_activity_participations,
    numericality: { greater_than_or_equal_to: 1, allow_blank: true }
  validates :paid_missing_activity_participations_amount,
    numericality: { greater_than_or_equal_to: 1 },
    if: :paid_missing_activity_participations,
    on: :create
  validates :acp_shares_number,
    numericality: { other_than: 0, allow_blank: true }
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

  after_commit :process!, on: :create
  after_commit :update_membership_activity_participations_accepted!

  def self.object_types
    types = %w[Membership Other]
    types << 'ActivityParticipation' if Current.acp.feature?('activity')
    types << 'GroupBuying::Order' if Current.acp.feature?('group_buying')
    types << 'AnnualFee' if Current.acp.annual_fee?
    types << 'ACPShare' if Current.acp.share?
    types
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[balance_equals balance_greater_than balance_less_than]
  end

  def display_name
    "#{model_name.human} ##{id} (#{I18n.l date})"
  end

  def send!
    return unless can_send_email?
    raise UnprocessedError if processing?

    MailTemplate.deliver_later(:invoice_created, invoice: self)
    touch(:sent_at)
    close_or_open!
  rescue => e
    ExceptionNotifier.notify(e,
      invoice_id: id,
      emails: member.emails,
      member_id: member_id)
    Sentry.capture_exception(e, extra: {
      invoice_id: id,
      emails: member.emails,
      member_id: member_id
    })
  end

  def mark_as_sent!
    return if sent_at?
    invalid_transition(:mark_as_sent!) if processing?

    touch(:sent_at)
    close_or_open!
  end

  def cancel!
    invalid_transition(:close!) unless can_cancel?

    transaction do
      update!(
        canceled_at: Time.current,
        state: CANCELED_STATE)
      Payment.redistribute!(member_id)
      handle_acp_shares_change!
    end
  end

  def close_or_open!
    return if processing?
    invalid_transition(:update_state!) if canceled?

    if missing_amount.zero?
      update!(state: CLOSED_STATE)
    elsif sent_at?
      update!(state: OPEN_STATE)
    else
      update!(state: NOT_SENT_STATE)
    end
  end

  def overpaid?
    payments.sum(:amount) > amount
  end

  def send_overpaid_notification_to_admins!
    return if overpaid_notification_sent_at?
    return unless overpaid?

    Admin.notify!(:invoice_overpaid,
      member: member,
      invoice: self)
    touch(:overpaid_notification_sent_at)
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

  def membership_amount_fraction
    @membership_amount_fraction || 1 # bill for everything by default
  end

  def amount=(*_args)
    raise NoMethodError, 'is set automaticaly.'
  end

  def paid_amount=(*_args)
    raise NoMethodError, 'is set automaticaly.'
  end

  def memberships_amount=(*_args)
    raise NoMethodError, 'is set automaticaly.'
  end

  def remaining_memberships_amount=(*_args)
    raise NoMethodError, 'is set automaticaly.'
  end

  def items_attributes=(attrs)
    return if attrs.empty?

    super
    self[:object_type] = 'Other' unless object_type?
    self[:amount] = items.sum(&:amount)
  end

  def paid_missing_activity_participations=(number)
    return if number.blank?

    super
    self[:object_type] = 'ActivityParticipation' unless object_type?
  end

  def paid_missing_activity_participations_amount=(amount)
    @paid_missing_activity_participations_amount = amount
    if activity_participation_type?
      self[:amount] = amount
    end
  end

  def acp_shares_number=(number)
    return if number.to_i == 0

    super
    self[:object_type] = 'ACPShare' unless object_type?
    self[:amount] = number.to_i * Current.acp.share_price
  end

  def can_destroy?
    !sent_at? && payments.none?
  end

  def can_cancel?
    !canceled? && (not_sent? || open? || current_year?)
  end

  def can_send_email?
    !sent_at? && !canceled? && member.emails?
  end

  def can_refund?
    closed? &&
      acp_shares_number.to_i.positive? &&
      member.acp_shares_number.to_i.positive?
  end

  def membership_type?
    object_type == 'Membership'
  end

  def activity_participation_type?
    object_type == 'ActivityParticipation'
  end

  def acp_share_type?
    object_type == 'ACPShare'
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

  def process!
    return unless processing?

    Payment.redistribute!(member_id)
    handle_acp_shares_change!
    reload # ensure that paid_amount/state change are reflected.
    set_pdf!
    Payment.redistribute!(member_id)
    update!(state: NOT_SENT_STATE)
    close_or_open!

    send! if @send_email
  end

  def handle_acp_shares_change!
    member.handle_acp_shares_change! if acp_share_type?
  end

  def set_pdf!
    I18n.with_locale(member.language) do
      invoice_pdf = PDF::Invoice.new(self)
      pdf_file.attach(
        io: StringIO.new(invoice_pdf.render),
        filename: "invoice-#{id}.pdf",
        content_type: 'application/pdf')
    end
  end

  def update_membership_activity_participations_accepted!
    if activity_participation_type?
      member.membership(fy_year)&.update_activity_participations_accepted!
    end
  end
end
