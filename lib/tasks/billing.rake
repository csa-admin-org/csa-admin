namespace :billing do
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
end
