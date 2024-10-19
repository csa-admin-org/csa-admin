# frozen_string_literal: true

require "rails_helper"

describe MembershipMailer, freeze: "2022-01-01" do
  specify "#last_trial_basket_email" do
    template = MailTemplate.find_by(title: "membership_last_trial_basket")
    member = create(:member, emails: "example@csa-admin.org")
    membership = create(:membership, member: member)
    basket = membership.baskets.trial.last
    mail = MembershipMailer.with(
      template: template,
      basket: basket,
    ).last_trial_basket_email

    expect(mail.subject).to eq("Dernier panier à l'essai!")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("membership-last-trial-basket")
    expect(mail.body).to include("C'est le jour de votre dernier panier à l'essai...")
    expect(mail.body).to include("https://membres.organization.test")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@organization.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"
  end

  specify "#renewal_email" do
    template = MailTemplate.find_by(title: "membership_renewal")
    member = create(:member, emails: "example@csa-admin.org")
    membership = create(:membership, member: member)
    mail = MembershipMailer.with(
      template: template,
      membership: membership,
    ).renewal_email

    expect(mail.subject).to eq("Renouvellement de votre abonnement")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("membership-renewal")
    expect(mail.body).to include("Accéder au formulaire de renouvellement")
    expect(mail.body).to include("https://membres.organization.test/memberships#renewal")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@organization.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"
  end

  specify "#renewal_reminder_email" do
    template = MailTemplate.find_by(title: "membership_renewal_reminder")
    member = create(:member, emails: "example@csa-admin.org")
    membership = create(:membership, member: member)
    mail = MembershipMailer.with(
      template: template,
      membership: membership,
    ).renewal_reminder_email

    expect(mail.subject).to eq("Renouvellement de votre abonnement (Rappel)")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("membership-renewal-reminder")
    expect(mail.body).to include("Accéder au formulaire de renouvellement")
    expect(mail.body).to include("https://membres.organization.test/memberships#renewal")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@organization.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"
  end
end
