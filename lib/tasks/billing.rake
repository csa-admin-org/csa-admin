namespace :billing do
  desc 'Automatically Create and send new invoices'
  task recurring: :environment do
    ACP.enter_each! do
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
    ACP.enter_each! do
      if Current.acp.credentials(:ebics) || Current.acp.credentials(:bas)
        Invoice.open.each { |invoice| InvoiceOverdueNoticer.perform(invoice) }
        puts "#{Current.acp.name}: Invoice overdue notices sent."
      end
    end
  end

  desc 'Process all new payments'
  task process_payments: :environment do
    ACP.enter_each! do
      if ebics_credentials = Current.acp.credentials(:ebics)
        provider = Billing::EBICS.new(ebics_credentials)
        PaymentsProcessor.new(provider).process
        puts "#{Current.acp.name}: New EBICS payments processed."
      end
      if bas_credentials = Current.acp.credentials(:bas)
        provider = Billing::BAS.new(bas_credentials)
        if Current.acp.invoice_type == 'ISR'
          PaymentsProcessor.new(provider).process
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

  desc 'Create or update quarter snapshot'
  task snapshot: :environment do
    ACP.enter_each! do
      max = Current.fiscal_year.current_quarter_range.max
      range = (max - 1.hour)..max
      if 30.seconds.from_now.in?(range)
        Billing::Snapshot.create_or_update_current_quarter!
      end
    end
  end
end
