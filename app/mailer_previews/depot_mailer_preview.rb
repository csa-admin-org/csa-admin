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
    martha = Member.new(id: 1, name: "Martha")
    bob = Member.new(id: 2, name: "Bob")
    josh = Member.new(id: 3, name: "Josh")
    overlay = HomeDeliveryAddress.new(
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel")
    baskets = [
      OpenStruct.new(member: martha, description: "Petit Panier"),
      OpenStruct.new(member: bob, description: "Grand Panier"),
      OpenStruct.new(member: josh, description: "Petit Panier")
    ]
    DepotMailer.with(
      depot: depot,
      baskets: baskets,
      delivery: delivery,
      overlays: { bob.id => overlay }
    ).delivery_list_email
  end
end
