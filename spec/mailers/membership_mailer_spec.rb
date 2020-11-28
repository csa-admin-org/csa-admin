require 'rails_helper'

describe MembershipMailer do
  specify '#renewal_email' do
    template = MailTemplate.create!(title: 'membership_renewal')
    member = create(:member, emails: 'example@acp-admin.ch')
    membership = create(:membership, member: member)
    mail = MembershipMailer.with(
      template: template,
      membership: membership,
    ).renewal_email

    expect(mail.subject).to eq('Renouvellement de votre abonnement')
    expect(mail.to).to eq(['example@acp-admin.ch'])
    expect(mail.body).to include('Accéder au formulaire de renouvellement')
    expect(mail.body).to include('https://membres.ragedevert.ch/membership#renewal')
    expect(mail.from).to eq 'Rage de Vert info@ragedevert.ch'
  end

  specify '#renewal_reminder_email' do
    template = MailTemplate.create!(title: 'membership_renewal_reminder')
    member = create(:member, emails: 'example@acp-admin.ch')
    membership = create(:membership, member: member)
    mail = MembershipMailer.with(
      template: template,
      membership: membership,
    ).renewal_reminder_email

    expect(mail.subject).to eq('Renouvellement de votre abonnement (Rappel)')
    expect(mail.to).to eq(['example@acp-admin.ch'])
    expect(mail.body).to include('Accéder au formulaire de renouvellement')
    expect(mail.body).to include('https://membres.ragedevert.ch/membership#renewal')
    expect(mail.from).to eq 'Rage de Vert info@ragedevert.ch'
  end
end
