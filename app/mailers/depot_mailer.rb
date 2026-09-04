# frozen_string_literal: true

class DepotMailer < ApplicationMailer
  def delivery_list_email
    depot = params[:depot]
    delivery = params[:delivery]
    baskets = params[:baskets] || depot.baskets_for(delivery)
    I18n.with_locale(depot.language) do
      xlsx = XLSX::Delivery.new(delivery, depot)
      attachments[xlsx.filename] = {
        mime_type: xlsx.content_type,
        content: xlsx.data
      }
      pdf = PDF::Delivery.new(delivery, depot)
      attachments[pdf.filename] = {
        mime_type: pdf.content_type,
        content: pdf.render
      }
      overlays = params[:overlays] || HomeDeliveryAddress.by_member_id_for(delivery, baskets.map(&:member))
      basket_drops = baskets.map { |b|
        Liquid::AdminBasketDrop.new(b, overlay: overlays[b.member.id])
      }
      content = liquid_template.render(
        "depot" => Liquid::DepotDrop.new(depot),
        "baskets" => basket_drops,
        "delivery" => Liquid::DeliveryDrop.new(delivery),
        "temporary_address" => basket_drops.any?(&:temporary_address))
      content_mail(content,
        to: depot.emails_array,
        subject: t(".subject",
          date: I18n.l(delivery.date),
          depot: depot.name),
        tag: "depot-delivery-list")
    end
  end
end
