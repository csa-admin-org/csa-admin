# frozen_string_literal: true

require "rounding"
require "bigdecimal"
require "stringio"

class Invoice < ApplicationRecord
  include HasFiscalYear
  include HasState
  include HasComment
  include Auditable
  include HasAttachments
  include HasCurrency
  include ActionView::Helpers::NumberHelper

  # Sub-model concerns (order matters for callbacks!)
  include EntityType
  include SEPA
  include Processing
  include MembershipBilling
  include ActivityParticipationBilling
  include SharesBilling
  include Amounts

  UnprocessedError = Class.new(StandardError)

  attribute :activity_price, :decimal, default: -> { Current.org.activity_price }
  attr_writer :membership_amount_fraction, :send_email

  has_states :processing, :open, :closed, :canceled

  audited_attributes :state, :sent_at, :sepa_direct_debit_order_uploaded_at

  belongs_to :member
  has_many :items, class_name: "InvoiceItem", dependent: :destroy
  has_many :payments, dependent: :destroy

  accepts_nested_attributes_for :items, allow_destroy: true

  validates :member, presence: true
  validates :date, presence: true
  validate :organization_iban_must_be_present

  before_create :set_local_currency_code
  before_destroy :ensure_latest_invoice!
  after_destroy -> { self.class.reset_pk_sequence! }
  after_destroy -> { Billing::PaymentsRedistributor.redistribute!(member_id) }

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[
      balance_eq balance_gt balance_lt
      sent_eq sepa_eq
      activity_participations_fiscal_year
      membership_eq
    ]
  end

  def display_name
    "#{document_name} ##{id} (#{I18n.l date, format: :short})"
  end

  def document_name
    Current.org.invoice_document_name || model_name.human
  end

  def reference
    Billing.reference.new(self)
  end

  def attachments
    if entity&.respond_to?(:attachments)
      entity.attachments
    else
      super
    end
  end

  def latest?
    id == self.class.maximum(:id)
  end

  def entity_latest?
    return false unless entity_id?

    id == self.class.not_canceled.same_entity(self).maximum(:id)
  end

  def previously_canceled_entity_invoice_ids
    return [] unless entity_id?

    ids = []
    invoices = self.class.same_entity(self).where(id: ...id).order(id: :desc)
    invoices.each do |invoice|
      if invoice.canceled?
        ids << invoice.id
      else
        break
      end
    end
    ids.sort
  end

  def items_attributes=(attrs)
    return if attrs.empty?

    super
    self[:entity_type] = "Other" unless entity_type?
    self[:amount] = items.reject(&:marked_for_destruction?).sum(&:amount)
  end

  private

  def set_local_currency_code
    return unless Current.org.feature?(:local_currency)
    return unless member&.use_local_currency?

    self.currency_code = Current.org.local_currency_code
  end

  def organization_iban_must_be_present
    return if Current.org.iban?

    errors.add(:base, :missing_iban)
  end

  def ensure_latest_invoice!
    throw :abort unless latest?
  end
end
