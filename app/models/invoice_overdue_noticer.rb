class InvoiceOverdueNoticer
  DAYS_DELAY = 35.days.freeze
  attr_reader :invoice

  def self.perform(*args)
    new(*args).perform
  end

  def initialize(invoice)
    @invoice = invoice
  end

  def perform
    return unless overdue_noticable?

    invoice.increment(:overdue_notices_count)
    invoice.overdue_notice_sent_at = Time.current
    invoice.save!

    MailTemplate.deliver_later(:invoice_overdue_notice, invoice: invoice)

    if invoice.overdue_notices_count == 3
      Admin.notify!(:invoice_third_overdue_notice, invoice: invoice)
    end
  rescue => e
    Sentry.capture_exception(e, extra: {
      invoice_id: invoice.id,
      emails: invoice.member.emails,
      member_id: invoice.member_id
    })
  end

  private

  def overdue_noticable?
    invoice.open? &&
      last_sent_at &&
      last_sent_at < DAYS_DELAY.ago &&
      invoice.member.billing_emails?
  end

  def last_sent_at
    invoice.overdue_notice_sent_at || invoice.sent_at
  end
end
