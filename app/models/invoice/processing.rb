# frozen_string_literal: true

# Handles invoice processing, state transitions, and lifecycle operations.
# This includes processing new invoices, sending emails, cancellation,
# and PDF generation.
module Invoice::Processing
  extend ActiveSupport::Concern

  included do
    has_one_attached :pdf_file

    scope :not_processing, -> { where.not(state: Invoice::PROCESSING_STATE) }
    scope :not_canceled, -> { where.not(state: Invoice::CANCELED_STATE) }
    scope :sent, -> { where.not(sent_at: nil) }
    scope :not_sent, -> { where(sent_at: nil) }
    scope :sent_eq, ->(bool) { ActiveRecord::Type::Boolean.new.cast(bool) ? sent : not_sent }
    scope :history, -> { not_processing.where.not(state: Invoice::OPEN_STATE) }
    scope :with_overdue_notice, -> { unpaid.where(overdue_notices_count: 1..) }

    after_commit :enqueue_processing, on: :create
    after_commit :enqueue_cancellation, on: :update
  end

  def process!(send_email: false)
    return unless processing?

    Billing::PaymentsRedistributor.redistribute!(member_id)
    handle_shares_change!
    reload # ensure that paid_amount/state change are reflected.
    attach_pdf
    Billing::PaymentsRedistributor.redistribute!(member_id)
    transaction do
      update!(state: Invoice::OPEN_STATE)
      close_or_open!
      send! if send_email && (Current.org.send_closed_invoice? || open?)
    end
  end

  def send!
    return unless can_send_email?
    raise Invoice::UnprocessedError if processing?

    # Leave some time for the invoice PDF to be uploaded
    MailTemplate.deliver_later(:invoice_created, invoice: self)
    update!(sent_at: Time.current)
  rescue => e
    Error.report(e,
      invoice_id: id,
      emails: member.emails,
      member_id: member_id)
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
      @previous_state = state
      update!(
        canceled_at: Time.current,
        state: Invoice::CANCELED_STATE)
      Billing::PaymentsRedistributor.redistribute!(member_id)
      handle_shares_change!
    end
  end

  def uncancel!
    transaction do
      update!(
        canceled_at: nil,
        stamped_at: nil,
        state: Invoice::OPEN_STATE)
      Billing::PaymentsRedistributor.redistribute!(member_id)
      handle_shares_change!
    end
    attach_pdf
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

    self.state = missing_amount.zero? ? Invoice::CLOSED_STATE : Invoice::OPEN_STATE
    save!(validate: false)
  end

  def stamp_pdf_as_canceled!
    raise "invoice #{id} not canceled!" unless canceled?
    raise "invoice #{id} already stamped!" if stamped_at?

    pdf_file.open do |file|
      I18n.with_locale(member.language) do
        PDF::InvoiceCancellationStamp.stamp!(file.path)
      end
      pdf_file.attach(
        io: File.open(file.path),
        filename: pdf_filename,
        content_type: "application/pdf")
    end
    touch(:stamped_at)
    Rails.event.notify(:invoice_cancellation_stamped, invoice_id: id)
  end

  def processed?
    !processing?
  end

  def sent?
    sent_at?
  end

  def can_send_email?
    can_be_mark_as_sent? && member.billing_emails?
  end

  def can_be_mark_as_sent?
    !processing? && !sent_at? && !canceled?
  end

  def can_update?
    !sent? && other_type?
  end

  def can_destroy_or_cancel?
    can_destroy? || can_cancel?
  end

  def can_destroy?
    latest? && !processing? && !sent? && payments.none?
  end

  def can_cancel?
    !can_destroy?
      && !processing?
      && !canceled?
      && (current_year? || open? || (activity_participation_type? && last_year?) || (membership_type? && entity.current_year?))
      && (!share_type? || open?)
      && (!entity_id? || entity_latest?)
  end

  def attach_pdf
    return if Rails.env.test? && Thread.current[:skip_invoice_pdf]

    I18n.with_locale(member.language) do
      invoice_pdf = PDF::Invoice.new(self)
      pdf_file.attach(
        io: StringIO.new(invoice_pdf.render),
        filename: pdf_filename,
        content_type: "application/pdf")
    end
  end

  def pdf_filename
    [
      document_name.downcase.parameterize,
      Tenant.current,
      id
    ].join("-") + ".pdf"
  end

  def created_by
    audits.find_change_of(:state, from: Invoice::PROCESSING_STATE)&.actor
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

    audits.reversed.find_change_of(:state, to: Invoice::CANCELED_STATE)&.actor
  end

  private

  def closed_audit
    return unless closed?

    @closed_audit ||= audits.reversed.find_change_of(:state, to: Invoice::CLOSED_STATE)
  end

  def enqueue_processing
    Billing::InvoiceProcessorJob.perform_later(self, send_email: @send_email)
  end

  def enqueue_cancellation
    return unless saved_change_to_state?
    return unless canceled?

    Billing::InvoiceCancellationJob.perform_later(self,
      send_email: @previous_state == Invoice::OPEN_STATE)
  end
end
