# frozen_string_literal: true

require "ostruct"

class BasketComplementMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def weekly_summary_email
    basket_complement = BasketComplement.new(
      names: { I18n.locale.to_s => "Bread" },
      language: I18n.locale,
      emails: "supplier@example.com")
    deliveries_counts = [
      { delivery: Delivery.new(date: Date.new(2024, 6, 10)), count: 25 },
      { delivery: Delivery.new(date: Date.new(2024, 6, 13)), count: 18 }
    ]
    BasketComplementMailer.with(
      basket_complement: basket_complement,
      deliveries_counts: deliveries_counts
    ).weekly_summary_email
  end
end
