class DistributionMailer < ApplicationMailer
  layout false

  def next_delivery(distribution, delivery)
    @baskets = distribution.baskets.not_absent.joins(:member).where(delivery_id: delivery.id).order('members.name')

    xlsx = XLSX::Delivery.new(delivery, distribution)
    attachments[xlsx.filename] = {
      mime_type: xlsx.content_type,
      content: xlsx.data
    }

    mail \
      to: distribution.emails_array,
      subject: "#{Current.acp.name}: Liste livraison du #{l delivery.date}"
  end
end
