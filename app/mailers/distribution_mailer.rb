class DistributionMailer < ApplicationMailer
  layout false

  def next_delivery(distribution, delivery)
    @distribution = distribution
    @delivery = delivery
    @baskets = @distribution.baskets.where(delivery_id: @delivery.id).sort_by { |b| b.member.name }

    mail \
      to: @distribution.emails_array,
      subject: "#{Current.acp.name}: Liste livraison du #{l delivery.date}"
  end
end
