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
    Billing::PaymentsRedistributor.redistribute!(member_id)
  end
end
