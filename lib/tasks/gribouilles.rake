namespace :gribouilles do
  desc 'Create and send new invoices'
  task deliver: :environment do
    next_delivery = Delivery.coming.first
    if next_delivery && Time.zone.today == (next_delivery.date - 1.day)
      gribouille = next_delivery.gribouille
      if gribouille&.deliverable?
        Member.gribouille_emails.each do |email|
          begin
            GribouilleMailer.basket(gribouille, email).deliver_now
          rescue => ex
            ExceptionNotifier.notify_exception(ex, data: { email: email })
          end
        end
        gribouille.touch(:sent_at)
        p 'Gribouilles sent.'
      end
    end
  end
end
