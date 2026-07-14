# frozen_string_literal: true

class BasketComplementMailer < ApplicationMailer
  def delivery_count_email
    @basket_complement = params[:basket_complement]
    delivery = params[:delivery]
    count = params[:count]

    I18n.with_locale(@basket_complement.language) do
      delivery_date = I18n.l(delivery.date, format: :long_no_year)
      content = liquid_template.render(
        "basket_complement" => @basket_complement.name,
        "delivery_date" => delivery_date,
        "count" => count)
      content_mail(content,
        to: @basket_complement.emails_array,
        subject: t(".subject", complement: @basket_complement.name, date: delivery_date),
        tag: "basket-complement-delivery-count")
    end
  end
end
