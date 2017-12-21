require 'rounding'
require 'bigdecimal'

class Invoice < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  NoPdfError = Class.new(StandardError)

  attr_accessor :memberships_amount_fraction

  belongs_to :member

  mount_uploader :pdf, PdfUploader

  scope :current_year, -> { during_year(Time.zone.today.year) }
  scope :during_year, ->(year) {
    date = Date.new(year)
    where('date >= ? AND date <= ?', date.beginning_of_year, date.end_of_year)
  }
  scope :quarter, ->(n) { where('EXTRACT(QUARTER FROM date) = ?', n) }
  scope :support, -> { where.not(support_amount: nil) }
  scope :membership, -> { where.not(memberships_amount: nil) }
  scope :not_sent, -> { where(sent_at: nil) }
  scope :sent, -> { where.not(sent_at: nil) }
  scope :open, -> { sent.where('balance < amount') }
  scope :closed, -> { sent.where('balance >= amount') }
  scope :overbalance, -> { where('balance > amount') }
  scope :with_overdue_notice, -> { open.where('overdue_notices_count > 0') }

  before_validation \
    :set_paid_memberships_amount,
    :set_remaining_memberships_amount,
    :set_memberships_amount,
    :set_amount

  validate :validate_memberships_amounts_data
  validates :member, presence: true
  validates :date, presence: true, uniqueness: { scope: :member_id }
  validates :memberships_amount_fraction, inclusion: { in: [1, 2, 3, 4] }
  validates :manual_balance, presence: true, numericality: true
  validates :paid_memberships_amount,
    numericality: { greater_than_or_equal_to: 0 },
    allow_nil: true
  validates :memberships_amount,
    numericality: { greater_than: 0 },
    allow_nil: true
  validates :memberships_amounts_data,
    presence: true,
    unless: -> { support_amount? }
  validates :memberships_amount_description,
    presence: true,
    if: -> { memberships_amount? }
  validates :member_billing_interval,
    presence: true,
    inclusion: { in: Member::BILLING_INTERVALS }
  validate :validate_memberships_amount_for_current_year, on: :create

  before_save :set_isr_balance_and_balance

  def status
    return :not_sent unless sent_at?
    balance < amount ? :open : :closed
  end

  def sent?
    sent_at?
  end

  def sendable?
    !sent? && member.emails?
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

  def display_status
    I18n.t("invoice.status.#{status}")
  end

  def memberships_amount_fraction
    @memberships_amount_fraction || 1 # bill for everything by default
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

  def isr_balance=(_)
    raise NoMethodError, 'is set automaticaly.'
  end

  def memberships_amounts
    (memberships_amounts_data || []).sum do |m|
      if m.symbolize_keys[:price]
        BigDecimal.new(m.symbolize_keys[:price].to_s)
      end
    end
  end

  def memberships_amounts_data=(data)
    self[:memberships_amounts_data] = data && data.each do |hash|
      hash[:price] = hash[:price].round_to_five_cents if hash[:price]
    end
  end

  def add_note(text)
    self.note = "#{note}\n\n#{text}"
  end

  def collect_overbalances!
    overbalance_invoices = member.invoices.where.not(id: id).overbalance
    overbalance_invoices.each do |invoice|
      transaction do
        overbalance = invoice.overbalance
        invoice.decrement(:manual_balance, overbalance)
        invoice.add_note "Transférer #{number_to_currency(overbalance)} sur la facture ##{id}"
        increment(:manual_balance, overbalance)
        add_note "Réçu #{number_to_currency(overbalance)} de la facture ##{invoice.id}"
        invoice.save!
        save!
      end
    end
  end

  def set_pdf
    invoice_pdf = InvoicePdf.new(self, nil)
    virtual_file = VirtualFile.new(invoice_pdf.render, "invoice-#{id}.pdf")
    update_attribute(:pdf, virtual_file)
  end

  def send_email
    raise NoPdfError unless pdf?
    unless sent_at? || !member.emails?
      InvoiceMailer.new_invoice(self).deliver_now
      touch(:sent_at)
    end
  rescue => ex
    ExceptionNotifier.notify_exception(ex,
      data: { emails: member.emails, member: member })
  end

  def can_destroy?
    balance == 0
  end

  private

  def validate_memberships_amount_for_current_year
    return unless memberships_amounts_data?
    paid_invoices = member.invoices.membership.during_year(date.year)
    if paid_invoices.sum(:memberships_amount) + memberships_amount >
        memberships_amounts
      errors.add(:base, 'Somme de la facturation des abonnements trop grande')
    end
  end

  def validate_memberships_amounts_data
    if memberships_amounts_data && memberships_amounts_data.any? { |h|
      h.keys.map(&:to_s).sort != %w[
        basket_description
        basket_size_id
        basket_total_price
        description
        distribution_description
        distribution_id
        distribution_total_price
        halfday_works_description
        halfday_works_total_price
        id
        price
      ]
    }
      errors.add(:memberships_amounts_data)
    end
  end

  def set_paid_memberships_amount
    return unless memberships_amounts_data?
    paid_invoices = member.invoices.membership.during_year(date.year)
    self[:paid_memberships_amount] ||= paid_invoices.sum(:memberships_amount)
  end

  def set_remaining_memberships_amount
    return unless memberships_amounts_data?
    self[:remaining_memberships_amount] ||=
      memberships_amounts - paid_memberships_amount
  end

  def set_memberships_amount
    return unless memberships_amounts_data?
    amount = remaining_memberships_amount / memberships_amount_fraction.to_f
    self[:memberships_amount] ||= amount.round_to_five_cents
  end

  def set_amount
    self[:amount] = memberships_amount.to_f + support_amount.to_f
  end

  class VirtualFile < StringIO
    attr_accessor :original_filename

    def initialize(string, original_filename)
      @original_filename = original_filename
      super(string)
    end
  end

  def set_isr_balance_and_balance
    self[:isr_balance] = isr_balance_data.values.sum
    self[:balance] = isr_balance.to_f + manual_balance.to_f
  end
end
