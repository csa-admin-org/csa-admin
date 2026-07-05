# frozen_string_literal: true

module Invoice::SEPA
  extend ActiveSupport::Concern

  included do
    belongs_to :sepa_mandate, optional: true

    scope :sepa, -> { where.not(sepa_mandate_id: nil) }
    scope :not_sepa, -> { where(sepa_mandate_id: nil) }
    scope :sepa_eq, ->(bool) { ActiveRecord::Type::Boolean.new.cast(bool) ? sepa : not_sepa }

    before_validation :set_sepa_mandate, on: :create
  end

  def sepa?
    Current.org.sepa_configured? && sepa_mandate_id?
  end

  def sepa_debtor_name
    self[:sepa_debtor_name].presence || member&.billing_info(:name)
  end

  def sepa_direct_debit_pain_schema
    if Current.org.bank_connection_sepa_direct_debit_upload?
      bank_connection = Current.org.bank_connection
      return bank_connection.sepa_direct_debit_schema if bank_connection.respond_to?(:sepa_direct_debit_schema)
    end

    Billing::SEPADirectDebit::PAIN_008_001_08
  end

  def sepa_direct_debit_pain_xml(schema: sepa_direct_debit_pain_schema)
    Billing::SEPADirectDebit.new(self, schema: schema).xml
  end

  def sepa_direct_debit_order_uploaded?
    sepa_direct_debit_order_uploaded_at?
  end

  def sepa_direct_debit_order_uploaded_by
    return unless sepa_direct_debit_order_uploaded_at?

    audits.reversed.find_change_of(:sepa_direct_debit_order_uploaded_at, from: nil)&.actor
  end

  def sepa_direct_debit_order_uploadable?
    open?
      && sepa?
      && sent?
      && !sepa_direct_debit_order_uploaded?
      && Current.org.bank_connection_sepa_direct_debit_upload?
  end

  def sepa_direct_debit_order_automatic_upload_due?
    return unless sepa_direct_debit_order_uploadable?

    sepa_direct_debit_order_automatic_upload_scheduled_on <= Date.current
  end

  def sepa_direct_debit_order_automatic_upload_scheduled_on
    return unless sepa_direct_debit_order_uploadable?

    (sent_at + Billing::SEPADirectDebit::AUTOMATIC_ORDER_UPLOAD_DELAY).to_date
  end

  def upload_sepa_direct_debit_order
    return if Rails.env.development?
    return unless sepa_direct_debit_order_uploadable?

    pain_xml = sepa_direct_debit_pain_xml
    bank_connection = Current.org.bank_connection
    _transaction_id, order_id = bank_connection.sepa_direct_debit_upload(pain_xml)

    update!(
      sepa_direct_debit_order_id: order_id,
      sepa_direct_debit_order_uploaded_at: Time.current)
    Rails.event.notify(:sepa_direct_debit_order_uploaded,
      invoice_id: id,
      order_id: order_id)
    true
  rescue => e
    context = sepa_direct_debit_upload_context(
      error: e.class.name,
      error_message: e.message)
    Rails.error.report(e, context: context)
    Rails.event.notify(:sepa_direct_debit_order_upload_failed, **context.symbolize_keys)
    false
  end

  def sepa_direct_debit_upload_context(**attributes)
    Billing::EBICS::SafeContext.build(
      connection: Current.org.active_bank_connection,
      invoice_id: id,
      member_display_id: member&.display_id,
      **attributes)
  end

  private

  def set_sepa_mandate
    self.sepa_mandate ||= member&.current_sepa_mandate if Current.org.sepa_configured? && member&.sepa?
    self[:sepa_debtor_name] ||= member&.billing_info(:name) if sepa_mandate.present?
  end
end
