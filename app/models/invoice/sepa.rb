# frozen_string_literal: true

module Invoice::SEPA
  extend ActiveSupport::Concern

  included do
    scope :sepa, -> { where.not(sepa_metadata: {}) }
    scope :not_sepa, -> { where(sepa_metadata: {}) }
    scope :sepa_eq, ->(bool) { ActiveRecord::Type::Boolean.new.cast(bool) ? sepa : not_sepa }

    before_validation :set_sepa_metadata, on: :create
  end

  def sepa?
    Current.org.sepa_creditor_identifier? && sepa_metadata.present?
  end

  def sepa_direct_debit_pain_xml
    Billing::SEPADirectDebit.new(self).xml
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
      && Current.org.bank_connection?
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
    Rails.error.report(e, context: { invoice_id: id })
    Rails.event.notify(:sepa_direct_debit_order_upload_failed,
      invoice_id: id,
      error: e.class.name,
      error_message: e.message)
    false
  end

  private

  def set_sepa_metadata
    return unless member&.sepa?

    self.sepa_metadata = member.sepa_metadata
  end
end
