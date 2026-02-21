# frozen_string_literal: true

class InvoiceOverdueNotice
  DAYS_DELAY = 35.days.freeze
  attr_reader :invoice

  def self.deliver(*args)
    new(*args).deliver
  end

  def self.deliver_later(invoice)
    Billing::InvoiceOverdueNoticeJob.perform_later(invoice)
  end

  def initialize(invoice)
    @invoice = invoice
  end

  def deliver
    return unless deliverable?

    invoice.increment(:overdue_notices_count)
    invoice.overdue_notice_sent_at = Time.current
    invoice.attach_pdf # regenerate PDF
    invoice.save!

    # Leave some time for the new invoice PDF to be uploaded
    MailTemplate.deliver(:invoice_overdue_notice, invoice: invoice)

    if invoice.overdue_notices_count == 3
      Admin.notify!(:invoice_third_overdue_notice, invoice: invoice)
    end
  rescue => e
    Rails.error.report(e, context: {
      invoice_id: invoice.id,
      emails: invoice.member.emails,
      member_id: invoice.member_id
    })
  end

  private

  def deliverable?
    invoice.open?
      && !invoice.sepa?
      && last_sent_at
      && last_sent_at < DAYS_DELAY.ago
      && invoice.member.billing_emails?
  end

  def last_sent_at
    invoice.overdue_notice_sent_at || invoice.sent_at
  end
end
