# Preview all emails at http://localhost:3000/rails/mailers/distribution
class DistributionPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/distribution/next_delivery
  def next_delivery
    distribution = Distribution.find(3) # Vin Libre
    delivery = Delivery.next

    DistributionMailer.next_delivery(distribution, delivery)
  end
end
