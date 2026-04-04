# frozen_string_literal: true

class BasketComplementMailer < ApplicationMailer
  def weekly_summary_email
    @basket_complement = params[:basket_complement]
    deliveries_counts = params[:deliveries_counts]
    I18n.with_locale(@basket_complement.language) do
      content = liquid_template.render(
        "basket_complement" => @basket_complement.name,
        "deliveries_counts" => deliveries_counts.map { |dc|
          { "date" => I18n.l(dc[:delivery].date, format: :long_no_year), "count" => dc[:count] }
        },
        "total" => deliveries_counts.sum { |dc| dc[:count] })
      content_mail(content,
        to: @basket_complement.emails_array,
        subject: t(".subject",
          complement: @basket_complement.name,
          week: deliveries_counts.first[:delivery].date.cweek),
        tag: "basket-complement-weekly-summary")
    end
  end
end
