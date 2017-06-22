namespace :cache do
  desc 'Warm dashboard caches'
  task warm: :environment do
    year = Time.zone.today.year
    next_delivery = Delivery.coming.first

    MemberCount.all
    billing_totals = BillingTotal.all
    billing_totals_price = billing_totals.sum(&:price)
    InvoiceTotal.all(billing_totals_price)
    DistributionCount.all(next_delivery)
    HalfdayParticipationCount.all(year)
    Member.gribouille_emails
  end
end
