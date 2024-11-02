# frozen_string_literal: true

require "rails_helper"

describe MemberMailer do
  specify "#activated_email", freeze: "2021-01-01" do
    template = MailTemplate.find_by(title: "member_activated")
    create_deliveries(2)
    create(:basket_complement, name: "Pain", id: 1)
    create(:basket_complement, name: "Oeuf", id: 2)
    member = create(:member, emails: "example@csa-admin.org")
    membership = create(:membership,
      member: member,
      depot: create(:depot, id: 12, name: "Jardin de la main"),
      basket_size: create(:basket_size, id: 33, name: "Eveil"),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: 1 },
        "1" => { basket_complement_id: 2, quantity: 2 }
      })
    mail = MemberMailer.with(
      template: template,
      member: member,
    ).activated_email

    expect(mail.subject).to eq("Bienvenue!")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("member-activated")
    expect(mail.body).to include("<strong>Dépôt:</strong> Jardin de la main")
    expect(mail.body).to include("<strong>Taille panier:</strong> Eveil")
    expect(mail.body).to include("<strong>Compléments:</strong> Oeuf et Pain")
    expect(mail.body).to include("Accéder à ma page de membre")
    expect(mail.body).to include("https://membres.acme.test")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"
  end

  specify "#validated_email" do
    template = MailTemplate.find_by(title: "member_validated")
    member = create(:member, emails: "example@csa-admin.org")
    mail = MemberMailer.with(
      template: template,
      member: member
    ).validated_email

    expect(mail.subject).to eq("Inscription validée!")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("member-validated")
    expect(mail.body).to include("Position sur la liste d'attente: <strong>1</strong>")
    expect(mail.body).to include("Accéder à ma page de membre")
    expect(mail.body).to include("https://membres.acme.test")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"
  end
end
