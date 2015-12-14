namespace :invoices do
  desc 'Create and send new invoices'
  task create: :environment do
    Member.billable.each do |member|
      InvoiceCreator.new(member).create
    end
    p 'New invoice(s) created.'
  end
end
