require 'rounding'
require 'bigdecimal'

class Invoice < ApplicationRecord
  include HasFiscalYearScopes
  include HasState
  include Auditable
  include ActionView::Helpers::NumberHelper
  UnprocessedError = Class.new(StandardError)

  attribute :activity_price, :decimal, default: -> { Current.acp.activity_price }
  attr_writer :membership_amount_fraction, :send_email
  attr_accessor :comment

  has_states :processing, :open, :closed, :canceled

  audited_attributes :state, :sent_at

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
  scope :not_sent, -> { where(sent_at: nil) }
  scope :sent_eq, ->(bool) { ActiveRecord::Type::Boolean.new.cast(bool) ? sent : not_sent }
  scope :all_without_canceled, -> { not_processing.not_canceled }
  scope :history, -> { not_processing.where.not(state: OPEN_STATE) }
  scope :unpaid, -> { not_canceled.where('paid_amount < amount') }
  scope :overpaid, -> { not_canceled.where('amount > 0 AND paid_amount > amount') }
  scope :balance_equals, ->(amount) { where('(paid_amount - amount) = ?', amount) }
  scope :balance_greater_than, ->(amount) { where('(paid_amount - amount) > ?', amount) }
  scope :balance_less_than, ->(amount) { where('(paid_amount - amount) < ?', amount) }
  scope :with_overdue_notice, -> { unpaid.where('overdue_notices_count > 0') }
  scope :shop_order_type, -> { where(object_type: 'Shop::Order') }
  scope :activity_participation_type, -> { where(object_type: 'ActivityParticipation') }
  scope :other_type, -> { where(object_type: 'Other') }

  with_options if: :membership_type?, on: :create do
    before_validation \
      :set_paid_memberships_amount,
      :set_remaining_memberships_amount,
      :set_memberships_amount
  end
  before_validation :set_amount, :set_vat_rate_and_amount, on: :create

  validates :member, presence: true
  validates :date, presence: true
  validates :membership_amount_fraction, inclusion: { in: 1..12 }
  validates :object_type, inclusion: { in: proc { Invoice.object_types } }
  validates :amount, presence: true
  validates :amount_percentage,
    numericality: {
      greater_than_or_equal_to: -100,
      less_than_or_equal_to: 200,
      allow_nil: true
    }
  validates :paid_missing_activity_participations,
    numericality: { greater_than_or_equal_to: 1, allow_blank: true }
  validates :paid_missing_activity_participations,
    absence: true,
    unless: :activity_participation_type?
  validates :items, absence: true, if: :activity_participation_type?
  validates :activity_price,
    numericality: { greater_than_or_equal_to: 1 },
    if: :paid_missing_activity_participations,
    on: :create
  validates :acp_shares_number,
    numericality: { other_than: 0, allow_blank: true }
  validates :acp_shares_number, absence: true, unless: :acp_share_type?
  validates :items, absence: true, if: :acp_share_type?
  validates :paid_memberships_amount,
    numericality: { greater_than_or_equal_to: 0 },
    allow_nil: true
  validates :memberships_amount,
    numericality: { greater_than: 0 },
    allow_nil: true
  validates :vat_rate, numericality: { greater_or_equal_to_than: 0, allow_nil: true }
  validates :vat_amount, presence: true, if: :vat_rate
  validates :memberships_amount_description,
    presence: true,
    if: -> { memberships_amount? }
  validate :validate_memberships_amount_for_current_year,
    on: :create,
    if: :membership_type?

  after_commit :enqueue_processing, on: :create
  after_commit :update_membership_activity_participations_accepted!
  after_destroy -> { Billing::PaymentsRedistributor.redistribute!(member_id) }

  def self.object_types
    types = %w[Membership Other]
    types << 'ActivityParticipation'
    types << 'Shop::Order'
    types << 'AnnualFee'
    types << 'ACPShare'
    types
  end

  def self.used_object_types
    (%w[Membership Other] + pluck(:object_type)).uniq.sort
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[balance_equals balance_greater_than balance_less_than sent_eq]
  end

  def display_name
    "#{model_name.human} ##{id} (#{I18n.l date})"
  end

  def process!(send_email: false)
    return unless processing?

    Billing::PaymentsRedistributor.redistribute!(member_id)
    handle_acp_shares_change!
    reload # ensure that paid_amount/state change are reflected.
    attach_pdf
    Billing::PaymentsRedistributor.redistribute!(member_id)
    transaction do
      update!(state: OPEN_STATE)
      close_or_open!
      send! if send_email && (Current.acp.send_closed_invoice? || open?)
    end
  end

  def send!
    return unless can_send_email?
    raise UnprocessedError if processing?

    # Leave some time for the invoice PDF to be uploaded
    MailTemplate.deliver_later(:invoice_created, invoice: self, wait: 5.seconds)
    update!(sent_at: Time.current)
    close_or_open!
  rescue => e
    Sentry.capture_exception(e, extra: {
      invoice_id: id,
      emails: member.emails,
      member_id: member_id
    })
  end

  def mark_as_sent!
    return if sent_at?
    invalid_transition(:mark_as_sent!) if processing?

    update!(sent_at: Time.current)
    close_or_open!
  end

  def cancel!
    invalid_transition(:cancel!) unless can_cancel?

    transaction do
      update!(
        canceled_at: Time.current,
        state: CANCELED_STATE)
      Billing::PaymentsRedistributor.redistribute!(member_id)
      handle_acp_shares_change!
    end
  end

  def destroy_or_cancel!
    if can_destroy?
      destroy!
    elsif can_cancel?
      cancel!
    else
      invalid_transition(:destroy_or_cancel!)
    end
  end

  def close_or_open!
    return if processing?
    invalid_transition(:update_state!) if canceled?

    if missing_amount.zero?
      update!(state: CLOSED_STATE)
    else
      update!(state: OPEN_STATE)
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

  def acp_shares_number=(number)
    return if number.to_i == 0

    super
    self[:object_type] = 'ACPShare' unless object_type?
    self[:amount] = number.to_i * Current.acp.share_price
  end

  def processed?
    !processing?
  end

  def sent?
    sent_at?
  end

  def can_destroy?
    !processing? && !sent_at? && payments.none?
  end

  def can_cancel?
    !can_destroy? &&
      !processing? &&
      !canceled? &&
      (open? || current_year? || other_type?)
  end

  def can_send_email?
    can_be_mark_as_sent? && member.billing_emails?
  end

  def can_be_mark_as_sent?
    !processing? && !sent_at? && !canceled?
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

  def other_type?
    object_type == 'Other'
  end

  def amount_with_vat
    memberships_amount || amount
  end

  def amount_without_vat
    return amount_with_vat unless vat_amount

    amount_with_vat - vat_amount
  end

  def created_by
    audits.find_change_of(:state, from: PROCESSING_STATE)&.actor
  end

  def sent_by
    return unless sent_at?

    audits.reversed.find_change_of(:sent_at, from: nil)&.actor
  end

  def closed_by
    closed_audit&.actor
  end

  def closed_at
    closed_audit&.created_at
  end

  def canceled_by
    return unless canceled?

    audits.reversed.find_change_of(:state, to: CANCELED_STATE)&.actor
  end

  def attach_pdf
    I18n.with_locale(member.language) do
      invoice_pdf = PDF::Invoice.new(self)
      pdf_file.attach(
        io: StringIO.new(invoice_pdf.render),
        filename: "invoice-#{id}.pdf",
        content_type: 'application/pdf')
    end
  end

  private

  def closed_audit
    return unless closed?

    @closed_audit ||= audits.reversed.find_change_of(:state, to: CLOSED_STATE)
  end

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
    self[:amount] ||=
      if activity_participation_type? && activity_price
        paid_missing_activity_participations * activity_price
      else
        (memberships_amount || 0) + (annual_fee || 0)
      end
    apply_amount_percentage
  end

  def apply_amount_percentage
    if amount_percentage?
      self[:amount_before_percentage] = amount
      self[:amount] = (amount * (1 + amount_percentage / 100.0)).round_to_five_cents
    else
      self[:amount_before_percentage] = nil
    end
  end

  def set_vat_rate_and_amount
    if configured_vat_rate.presence&.positive?
      self[:vat_rate] = configured_vat_rate
      gross_amount = amount_with_vat
      net_amount = gross_amount / (1 + vat_rate / 100.0)
      self[:vat_amount] = gross_amount - net_amount.round(2)
    end
  end

  def enqueue_processing
    Billing::InvoiceProcessorJob.perform_later(self, send_email: @send_email)
  end

  def handle_acp_shares_change!
    member.handle_acp_shares_change! if acp_share_type?
  end

  def update_membership_activity_participations_accepted!
    if activity_participation_type?
      member.membership(fy_year)&.update_activity_participations_accepted!
    end
  end

  def configured_vat_rate
    case object_type
    when 'Membership'
      Current.acp.vat_membership_rate
    when 'ActivityParticipation'
      Current.acp.vat_activity_rate
    when 'Shop::Order'
      Current.acp.vat_shop_rate
    when 'Other'
      vat_rate
    end
  end
end
