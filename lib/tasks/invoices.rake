namespace :invoices do
  desc 'Create and send new invoices'
  task create: :environment do
    ACP.enter!('ragedevert')
    if Date.current.tuesday? && Date.current > Delivery.current_year.first.date
      Member.billable.each do |member|
        RecurringBilling.invoice(member, send_email: true)
      end
      p "#{Current.acp.name}: invoices created."
    end
  end

  desc 'Process all new payments'
  task process_payments: :environment do
    ACP.enter_each! do
      if raiffeisen_credentials = Current.acp.credentials(:raiffeisen)
        provider = Billing::Raiffeisen.new(raiffeisen_credentials)
        PaymentsProcessor.new(provider).process
        p 'All Raiffeisen payments processed.'
      end
      if bas_credentials = Current.acp.credentials(:bas)
        provider = Billing::BAS.new(bas_credentials)
        PaymentsProcessor.new(provider).process
        p 'All BAS payments processed.'
      end
    end
  end

  desc 'Send invoice overdue notices'
  task send_overdue_notices: :environment do
    ACP.enter_each! do
      Invoice.open.each { |invoice| InvoiceOverdueNoticer.perform(invoice) }
      p "#{Current.acp.name}: All invoice overdue notices sent."
    end
  end
end
