namespace :invoices do
  desc 'Create and send new invoices'
  task create: :environment do
    Member.billable.each do |member|
      InvoiceCreator.new(member).create
    end
    p 'New invoice(s) created.'
  end

  desc 'Update invoices isr balance data'
  task update_isr_balances: :environment do
    IsrBalanceUpdater.new.update_all
    p 'All invoices isr balance data updated.'
  end
end
