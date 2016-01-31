namespace :invoices do
  desc 'Create and send new invoices'
  task create: :environment do
    if Time.zone.today.tuesday? && Date.today > Delivery.current_year.first.date
      Member.billable.each do |member|
        begin
          invoice = InvoiceCreator.new(member).create
          invoice&.send_email
        rescue => ex
          ExceptionNotifier.notify_exception(ex,
            data: { member_id: member.id, invoice_id: invoice&.id }
          )
        end
      end
      p 'New invoice(s) created.'
    else
      p "It's not Tuesday dude."
    end
  end

  desc 'Update invoices isr balance data'
  task update_isr_balances: :environment do
    IsrBalanceUpdater.new.update_all
    p 'All invoices isr balance data updated.'
  end

  desc 'Send invoice overdue notices'
  task send_overdue_notices: :environment do
    Invoice.open.each { |invoice| InvoiceOverdueNoticer.perform(invoice) }
    p 'All invoice overdue notices sent.'
  end
end
