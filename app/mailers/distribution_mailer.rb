class DistributionMailer < ApplicationMailer
  layout false

  def next_delivery(distribution, delivery)
    @distribution = distribution
    @delivery = delivery
    @memberships = @distribution.memberships_for(@delivery).sort_by { |m| m.member.name }

    mail \
      to: @distribution.emails_array,
      cc: 'bichseld@gmail.com',
      subject: "Rage de Vert: Liste livraison du #{l delivery.date}"
  end
end
