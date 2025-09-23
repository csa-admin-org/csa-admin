# frozen_string_literal: true

class Payment < ApplicationRecord
  include HasFiscalYear
  include Auditable
  include HasCurrency

  attr_accessor :comment

  audited_attributes :member_id, :invoice_id, :date, :amount, :ignored_at

  default_scope { order(:date) }

  belongs_to :member
  belongs_to :invoice, optional: true

  scope :ignored, -> { where.not(ignored_at: nil) }
  scope :not_ignored, -> { where(ignored_at: nil) }
  scope :auto, -> { not_ignored.where.not(fingerprint: nil) }
  scope :manual, -> { not_ignored.where(fingerprint: nil) }
  scope :refund, -> { not_ignored.where("amount < 0") }
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
    fingerprint? ? "auto" : "manual"
  end

  def state
    ignored? ? "ignored" : type
  end

  def manual?
    type == "manual"
  end

  def auto?
    type == "auto"
  end

  def reversal?
    amount.negative?
  end

  def send_reversal_notification_to_admins!
    return if reversal_notification_sent_at?
    return unless reversal?

    Admin.notify!(:payment_reversal,
      member: member,
      payment: self)
    touch(:reversal_notification_sent_at)
  end

  def ignore!
    return unless can_ignore?

    update!(ignored_at: Time.current)
  end

  def can_ignore?
    auto? && !ignored?
  end

  def unignore!
    return unless can_unignore?

    update!(ignored_at: nil)
  end

  def can_unignore?
    auto? && ignored?
  end

  def ignored?
    ignored_at.present?
  end

  def ignored_by
    return unless ignored?

    audits.reversed.find_change_of(:ignored_at, from: nil)&.actor
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
