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
    invoice.overdue_notice_sent_at = Time.zone.now
    invoice.save!

    InvoiceMailer.overdue_notice(invoice).deliver_now
  rescue => ex
    ExceptionNotifier.notify_exception(ex,
      data: { emails: invoice.member.emails, member: invoice.member })
  end

  private

  def overdue_noticable?
    invoice.status == :open && last_sent_at < DAYS_DELAY.ago && member_emails?
  end

  def member_emails?
    invoice.member.emails?
  end

  def last_sent_at
    invoice.overdue_notice_sent_at || invoice.sent_at
  end
end
