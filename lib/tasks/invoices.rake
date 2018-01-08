namespace :invoices do
  desc 'Create and send new invoices'
  task create: :environment do
    ACP.switch_each! do
      if Time.zone.today.tuesday? && Date.today > Delivery.current_year.first.date
        Member.billable.each do |member|
          begin
            invoice = InvoiceCreator.new(member).create
            invoice&.send!
          rescue => ex
            ExceptionNotifier.notify_exception(ex,
              data: { member_id: member.id, invoice_id: invoice&.id }
            )
          end
        end
        p "#{Current.acp.name}: New invoice(s) created."
      else
        p "#{Current.acp.name}: It's not Tuesday dude."
      end
    end
  end

  desc 'Process all new payments'
  task process_payments: :environment do
    Apartment::Tenant.switch!('ragedevert')
    PaymentsProcessor.new.process
    p 'All payments processed.'
  end

  desc 'Send invoice overdue notices'
  task send_overdue_notices: :environment do
    ACP.switch_each! do
      Invoice.open.each { |invoice| InvoiceOverdueNoticer.perform(invoice) }
      p "#{Current.acp.name}: All invoice overdue notices sent."
    end
  end
end
