namespace :invoices do
  desc 'Create and send new invoices'
  task create: :environment do
    ACP.enter_each! do
      if Current.acp.feature?('recurring_billing') &&
          Date.current.tuesday? &&
          Date.current > Delivery.current_year.first.date
        Member.billable.each do |member|
          if Current.acp.share?
            Billing::MembershipACPShare.invoice!(member, send_email: true)
          end
          RecurringBilling.invoice(member, send_email: true)
        end
        puts "#{Current.acp.name}: New invoices created."
      end
    end
  end

  desc 'Process all new payments'
  task process_payments: :environment do
    ACP.enter_each! do
      if raiffeisen_softcert_credentials = Current.acp.credentials(:raiffeisen_softcert)
        provider = Billing::RaiffeisenSoftcert.new(raiffeisen_softcert_credentials)
        PaymentsProcessor.new(provider).process
        puts "#{Current.acp.name}: New Raiffeisen SoftCert payments processed."
      end
      if raiffeisen_ebics_credentials = Current.acp.credentials(:raiffeisen_ebics)
        provider = Billing::RaiffeisenEbics.new(raiffeisen_ebics_credentials)
        PaymentsProcessor.new(provider).process
        puts "#{Current.acp.name}: New Raiffeisen EBICS payments processed."
      end
      if bas_credentials = Current.acp.credentials(:bas)
        provider = Billing::BAS.new(bas_credentials)
        PaymentsProcessor.new(provider).process
        puts "#{Current.acp.name}: New BAS payments processed."
      end
    end
  end

  desc 'Send invoice overdue notices'
  task send_overdue_notices: :environment do
    ACP.enter_each! do
      Invoice.open.each { |invoice| InvoiceOverdueNoticer.perform(invoice) }
      puts "#{Current.acp.name}: Invoice overdue notices sent."
    end
  end
end
