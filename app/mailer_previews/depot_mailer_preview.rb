# frozen_string_literal: true

require "ostruct"

class DepotMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def delivery_list_email
    depot = Depot.new(
      name: "Jardin de la Main",
      language: I18n.locale,
      emails: "respondent1@csa-admin.org, respondent2@csa-admin.org")
    delivery = Delivery.new(date: Date.new(2020, 11, 10))
    baskets = [
      OpenStruct.new(
        member: Member.new(name: "Martha"),
        description: "Petit Panier"),
      OpenStruct.new(
        member: Member.new(name: "Bob"),
        description: "Grand Panier"),
      OpenStruct.new(
        member: Member.new(name: "Josh"),
        description: "Petit Panier")
    ]
    DepotMailer.with(
      depot: depot,
      baskets: baskets,
      delivery: delivery
    ).delivery_list_email
  end
end
