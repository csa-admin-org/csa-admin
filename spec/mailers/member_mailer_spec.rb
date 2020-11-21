require 'rails_helper'

describe MemberMailer do
  specify '#activated_email' do
    template = MailTemplate.create!(title: 'member_activated')
    member = create(:member, emails: 'example@acp-admin.ch')
    membership = create(:membership,
      member: member,
      depot: create(:depot, id: 12, name: 'Jardin de la main'),
      basket_size: create(:basket_size, id: 33, name: 'Eveil'))
    mail = MemberMailer.with(
      template: template,
      member: member,
      membership: membership,
    ).activated_email

    expect(mail.subject).to eq('Bienvenue!')
    expect(mail.to).to eq(['example@acp-admin.ch'])
    expect(mail.body).to include('<strong>Dépôt:</strong> Jardin de la main')
    expect(mail.body).to include('<strong>Taille panier:</strong> Eveil')
    expect(mail.body).to include('Accéder à ma page de membre')
    expect(mail.body).to include('https://membres.ragedevert.ch')
    expect(mail.from).to eq 'Rage de Vert info@ragedevert.ch'
  end

  specify '#validated_email' do
    template = MailTemplate.create!(title: 'member_validated')
    member = create(:member, emails: 'example@acp-admin.ch')
    mail = MemberMailer.with(
      template: template,
      member: member
    ).validated_email

    expect(mail.subject).to eq('Inscription validée!')
    expect(mail.to).to eq(['example@acp-admin.ch'])
    expect(mail.body).to include("Position sur la liste d'attente: <strong>1</strong>")
    expect(mail.body).to include('Accéder à ma page de membre')
    expect(mail.body).to include('https://membres.ragedevert.ch')
    expect(mail.from).to eq 'Rage de Vert info@ragedevert.ch'
  end
end
