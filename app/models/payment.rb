class Payment < ApplicationRecord
  include HasFiscalYearScopes
  include Auditable

  attr_accessor :comment

  audited_attributes :member_id, :invoice_id, :date, :amount

  default_scope { order(:date) }

  belongs_to :member
  belongs_to :invoice, optional: true

  scope :qr, -> { where.not(fingerprint: nil) }
  scope :manual, -> { where(fingerprint: nil) }
  scope :refund, -> { where('amount < 0') }
  scope :invoice_id_eq, ->(id) { where(invoice_id: id) }

  validates :date, presence: true
  validates :amount, numericality: { other_than: 0 }, presence: true
  validates :fingerprint, uniqueness: true, allow_nil: true

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
    fingerprint? ? 'qr' : 'manual'
  end

  def qr?
    type == 'qr'
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

  def created_by
    audits.find_change_of(:member_id, from: nil)&.actor
  end

  def updated?
    updated_at > created_at
  end

  def updated_by
    return unless updated?

    audits.last&.actor
  end

  private

  def redistribute!
    Billing::PaymentsRedistributor.redistribute!(member_id)
  end
end
