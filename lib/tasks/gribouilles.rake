namespace :gribouilles do
  desc 'Create and send new invoices'
  task deliver: :environment do
    next_delivery = Delivery.coming.first
    if next_delivery && Time.zone.today == (next_delivery.date - 1.day)
      gribouille = next_delivery.gribouille
      if gribouille&.deliverable?
        GribouilleMailer.basket(gribouille).deliver_now
        gribouille.touch(:sent_at)
        p 'Gribouille sent.'
      end
    end
  end
end
