# frozen_string_literal: true

class Notification::InvoiceOverdueNotice < Notification::Base
  def notify
    return unless Current.org.send_invoice_overdue_notice?

    Invoice.open.find_each do |invoice|
      InvoiceOverdueNotice.deliver_later(invoice)
    end
  end
end
