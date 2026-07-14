# frozen_string_literal: true

require "ostruct"

class BasketComplementMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def delivery_count_email
    basket_complement = BasketComplement.new(
      names: { I18n.locale.to_s => "Bread" },
      language: I18n.locale,
      emails: "supplier@example.com")
    BasketComplementMailer.with(
      basket_complement: basket_complement,
      delivery: Delivery.new(date: Date.new(2024, 6, 10)),
      count: 25
    ).delivery_count_email
  end
end
