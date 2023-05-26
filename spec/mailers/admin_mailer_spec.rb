require 'rails_helper'

describe AdminMailer do
  specify '#depot_delivery_list_email', freeze: '2020-01-01' do
    delivery = create(:delivery,
      date: Date.new(2020, 11, 6))
    depot = create(:depot,
      name: 'Jardin de la Main',
      language: I18n.locale,
      emails: 'respondent1@acp-admin.ch, respondent2@acp-admin.ch')
    create(:membership,
      member: create(:member, name: 'Martha'),
      basket_size: create(:basket_size, :small))
    create(:membership,
      member: create(:member, name: 'Charle'),
      basket_size: create(:basket_size, :big))
    mail = AdminMailer.with(
      depot: depot,
      baskets: Basket.all,
      delivery: delivery
    ).depot_delivery_list_email

    expect(mail.subject).to eq('Liste livraison du 6 novembre 2020 (Jardin de la Main)')
    expect(mail.to).to eq(['respondent1@acp-admin.ch', 'respondent2@acp-admin.ch'])
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'

    body = mail.html_part.body
    expect(body).to include('Voici la liste des membres:')
    expect(body).to include('<strong>Charle</strong>, Abondance')
    expect(body).to include('<strong>Martha</strong>, Eveil')
    expect(body).to include('Voir les pièces jointes pour plus de détails, merci.')

    expect(mail.attachments.size).to eq 2
    attachment1 = mail.attachments.first
    expect(attachment1.filename).to eq 'livraison-#1-20201106.xlsx'
    expect(attachment1.content_type).to eq 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml'
    attachment2 = mail.attachments.second
    expect(attachment2.filename).to eq 'fiches-signature-livraison-#1-20201106.pdf'
    expect(attachment2.content_type).to eq 'application/pdf'
  end

  specify '#delivery_list_email', freeze: '2023-01-01' do
    admin = Admin.new(
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    delivery = create(:delivery,
      id: 1,
      date: Date.new(2023, 11, 6))
    mail = AdminMailer.with(
      admin: admin,
      delivery: delivery
    ).delivery_list_email

    expect(mail.subject).to eq('Liste livraison du 6 novembre 2023')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'

    body = mail.html_part.body
    expect(body).to include('(XLSX)')
    expect(body).to include('(PDF)')
    expect(body).to include("Accéder à la page de la livraison")
    expect(body).to include('https://admin.ragedevert.ch/deliveries/1')

    expect(mail.attachments.size).to eq 2
    attachment1 = mail.attachments.first
    expect(attachment1.filename).to eq 'livraison-#1-20231106.xlsx'
    expect(attachment1.content_type).to eq 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml'
    attachment2 = mail.attachments.second
    expect(attachment2.filename).to eq 'fiches-signature-livraison-#1-20231106.pdf'
    expect(attachment2.content_type).to eq 'application/pdf'
  end

  specify '#invitation_email' do
    admin = Admin.new(
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    mail = AdminMailer.with(
      admin: admin,
      action_url: 'https://admin.ragedevert.ch'
    ).invitation_email

    expect(mail.subject).to eq("Invitation à l'admin de Rage de Vert")
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('admin@acp-admin.ch')
    expect(mail.body).to include("Accéder à l'admin de Rage de Vert")
    expect(mail.body).to include('https://admin.ragedevert.ch')
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'
  end

  specify '#invoice_overpaid_email' do
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(
      id: 2,
      name: 'Martha')
    invoice = Invoice.new(id: 42)
    mail = AdminMailer.with(
      admin: admin,
      member: member,
      invoice: invoice
    ).invoice_overpaid_email

    expect(mail.subject).to eq('Facture #42 payée en trop')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('Facture #42')
    expect(mail.body).to include('Martha')
    expect(mail.body).to include('Accéder à la page du membre')
    expect(mail.body).to include('https://admin.ragedevert.ch/members/2')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/1/edit#admin_notifications_input')
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'
  end

  specify '#invoice_third_overdue_notice_email' do
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(
      id: 2,
      name: 'Martha')
    invoice = Invoice.new(id: 42, member: member)
    mail = AdminMailer.with(
      admin: admin,
      invoice: invoice
    ).invoice_third_overdue_notice_email

    expect(mail.subject).to eq('Facture #42, 3ᵉ rappel envoyé')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include("Le 3ᵉ rappel vient d'être envoyé pour la facture #42")
    expect(mail.body).to include('Martha')
    expect(mail.body).to include('Accéder à la page du membre')
    expect(mail.body).to include('https://admin.ragedevert.ch/members/2')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/1/edit#admin_notifications_input')
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'
  end

  specify '#new_absence_email' do
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(name: 'Martha')
    absence = Absence.new(
      id: 1,
      started_on: Date.new(2020, 11, 10),
      ended_on: Date.new(2020, 11, 20))
    mail = AdminMailer.with(
      admin: admin,
      member: member,
      absence: absence
    ).new_absence_email

    expect(mail.subject).to eq('Nouvelle absence')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('Martha')
    expect(mail.body).to include('10 novembre 2020 au 20 novembre 2020')
    expect(mail.body).to include("Accéder à la page de l'absence")
    expect(mail.body).to include('https://admin.ragedevert.ch/absences/1')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/1/edit#admin_notifications_input')
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'
  end

  specify '#new_email_suppression_email' do
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    email_suppression = OpenStruct.new(
      reason: 'HardBounce',
      email: 'john@doe.com',
      owners: [
        Member.new(
          id: 2,
          name: 'Martha'),
        Admin.new(
          id: 4,
          name: 'Martha'
        )
      ])
    mail = AdminMailer.with(
      admin: admin,
      email_suppression: email_suppression
    ).new_email_suppression_email

    expect(mail.subject).to eq('Email rejeté (HardBounce)')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include("L'email <strong>john@doe.com</strong> a été rejeté lors de l'envoi du dernier message à cause de la raison suivante: <strong>HardBounce</strong>.")
    expect(mail.body).to include('Admin: Martha')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/4')
    expect(mail.body).to include('Membre: Martha')
    expect(mail.body).to include('https://admin.ragedevert.ch/members/2')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/1/edit#admin_notifications_input')
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'
  end

  specify '#new_inscription_email' do
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(
      id: 2,
      name: 'Martha')
    mail = AdminMailer.with(
      admin: admin,
      member: member
    ).new_inscription_email

    expect(mail.subject).to eq('Nouvelle inscription')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('Martha')
    expect(mail.body).to include("Accéder à la page du membre")
    expect(mail.body).to include('https://admin.ragedevert.ch/members/2')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/1/edit#admin_notifications_input')
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'
  end
end
