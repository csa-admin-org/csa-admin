namespace :billing do
  desc 'Automatically Create and send new invoices'
  task recurring: :environment do
    ACP.perform_each do
      today = Date.current
      if Current.acp.recurring_billing_wday == today.wday
        Member.find_each do |member|
          if Current.acp.share?
            Billing::ACPShare.invoice!(member, send_email: true)
          end
          recurring = RecurringBilling.new(member)
          if recurring.next_date == today
            recurring.invoice(send_email: true)
          end
        end
        puts "#{Current.acp.name}: New invoices created."
      end
    end
  end

  desc 'Send invoice overdue notices'
  task send_invoice_overdue_notices: :environment do
    ACP.perform_each do
      unless Current.acp.tenant_name == 'lafermedessavanes'
        if Current.acp.credentials(:ebics) || Current.acp.credentials(:bas)
          Invoice.open.each { |invoice| InvoiceOverdueNoticer.perform(invoice) }
          puts "#{Current.acp.name}: Invoice overdue notices sent."
        end
      end
    end
  end

  desc 'Process all new payments'
  task process_payments: :environment do
    ACP.perform_each do
      if ebics_credentials = Current.acp.credentials(:ebics)
        provider = Billing::EBICS.new(ebics_credentials)
        Billing::PaymentsProcessor.process!(provider.payments_data)
        puts "#{Current.acp.name}: New EBICS payments processed."
      end
      if bas_credentials = Current.acp.credentials(:bas)
        provider = Billing::BAS.new(bas_credentials)
        if Current.acp.isr_invoice?
          Billing::PaymentsProcessor.process!(provider.payments_data)
          puts "#{Current.acp.name}: New BAS payments processed."
        elsif provider.version != '2.10'
          ExceptionNotifier.notify(
            StandardError.new("NEW BAS VERSION!"),
            version: provider.version)
          Sentry.capture_message('NEW BAS VERSION!', extra: {
            version: provider.version
          })
        end
      end
    rescue => e
      ExceptionNotifier.notify(e)
      Sentry.capture_exception(e)
    end
  end
end
