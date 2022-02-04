class Payment < ApplicationRecord
  include HasFiscalYearScopes

  attr_accessor :comment

  default_scope { order(:date) }

  belongs_to :member
  belongs_to :invoice, optional: true

  scope :isr, -> { where.not(isr_data: nil) }
  scope :manual, -> { where(isr_data: nil) }
  scope :refund, -> { where('amount < 0') }
  scope :invoice_id_eq, ->(id) { where(invoice_id: id) }

  validates :date, presence: true
  validates :amount, numericality: { other_than: 0 }, presence: true
  validates :isr_data, uniqueness: true, allow_nil: true

  after_commit :redistribute!

  def self.redistribute!(member_id)
    member = Member.find(member_id)
    remaining_amount = 0

    transaction do
      member.invoices.update_all(paid_amount: 0)

      # Use payment amount to targeted invoice first.
      member.payments.each do |payment|
        if payment.invoice && !payment.invoice.canceled?
          paid_amount = [[payment.amount, payment.invoice.missing_amount].min, 0].max
          payment.invoice.increment!(:paid_amount, paid_amount)
          remaining_amount += payment.amount - paid_amount
        else
          remaining_amount += payment.amount
        end
      end

      # Add negative (payback) invoice to remaining_amount
      remaining_amount += -member.invoices.not_canceled.where('amount < 0').sum(:amount)

      # Split remaining amount on other invoices chronogically
      invoices = member.invoices.not_canceled.order(:date, :id)
      last_invoice = invoices.last
      invoices.each do |invoice|
        if invoice.missing_amount.positive? && remaining_amount.positive?
          paid_amount = invoice == last_invoice ? remaining_amount : [remaining_amount, invoice.missing_amount].min
          invoice.increment!(:paid_amount, paid_amount)
          remaining_amount -= paid_amount
        end
        invoice.reload.close_or_open!
      end
    end
  end

  def invoice_id=(invoice_id)
    super
    self.invoice = invoice if invoice
  end

  def invoice=(invoice)
    self.member = invoice.member
    super
  end

  def type
    isr_data? ? 'isr' : 'manual'
  end

  def isr?
    type == 'isr'
  end

  def manual?
    type == 'manual'
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[invoice_id_eq]
  end

  def can_destroy?
    manual?
  end

  def can_update?
    manual?
  end

  private

  def redistribute!
    self.class.redistribute!(member_id)
  end
end
