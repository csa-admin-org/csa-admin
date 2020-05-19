namespace :billing do
  desc 'Automatically Create and send new invoices'
  task recurring: :environment do
    ACP.enter_each! do
      if Current.acp.recurring_billing_wday &&
          Current.acp.recurring_billing_wday == Date.current.wday &&
          Delivery.current_year.any? &&
          Date.current > Delivery.current_year.first.date
        Member.find_each do |member|
          if Current.acp.share?
            Billing::MembershipACPShare.invoice!(member, send_email: true)
          end
          RecurringBilling.invoice(member, send_email: true)
        end
        puts "#{Current.acp.name}: New invoices created."
      end
    end
  end

  desc 'Send invoice overdue notices'
  task send_invoice_overdue_notices: :environment do
    ACP.enter_each! do
      Invoice.open.each { |invoice| InvoiceOverdueNoticer.perform(invoice) }
      puts "#{Current.acp.name}: Invoice overdue notices sent."
    end
  end

  desc 'Process all new payments'
  task process_payments: :environment do
    ACP.enter_each! do
      if raiffeisen_credentials = Current.acp.credentials(:raiffeisen)
        provider = Billing::Raiffeisen.new(raiffeisen_credentials)
        PaymentsProcessor.new(provider).process
        puts "#{Current.acp.name}: New Raiffeisen payments processed."
      end
      if bas_credentials = Current.acp.credentials(:bas)
        provider = Billing::BAS.new(bas_credentials)
        PaymentsProcessor.new(provider).process
        puts "#{Current.acp.name}: New BAS payments processed."
      end
    rescue => e
      ExceptionNotifier.notify(e)
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
