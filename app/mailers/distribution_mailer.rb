class DistributionMailer < ApplicationMailer
  layout false

  def next_delivery(distribution, delivery)
    @delivery = delivery
    @baskets = distribution.baskets
      .not_absent
      .joins(:member)
      .includes(:baskets_basket_complements)
      .where(delivery_id: delivery.id)
      .order('members.name')

    xlsx = XLSX::Delivery.new(delivery, distribution)
    attachments[xlsx.filename] = {
      mime_type: xlsx.content_type,
      content: xlsx.data
    }
    pdf = PDF::Delivery.new(delivery, distribution)
    attachments[pdf.filename] = {
      mime_type: pdf.content_type,
      content: pdf.render
    }

    mail \
      to: distribution.emails_array,
      subject: "#{Current.acp.name}: Liste livraison du #{l delivery.date}"
  end
end
