require 'rails_helper'

describe InvoiceMailer do
  specify '#created_email' do
    template = MailTemplate.create!(title: 'invoice_created')
    member = create(:member, emails: 'example@acp-admin.ch')
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: '24.03.2020',
      annual_fee: 62)

    mail = InvoiceMailer.with(
      template: template,
      member: member,
      invoice: invoice,
    ).created_email

    expect(mail.subject).to eq('Nouvelle facture #42')
    expect(mail.to).to eq(['example@acp-admin.ch'])
    body = mail.html_part.body
    expect(body).to include('Voici votre nouvelle facture')
    expect(body).to include('Accéder à ma page de membre')
    expect(body).to include('https://membres.ragedevert.ch/billing')
    expect(mail.from).to eq 'Rage de Vert info@ragedevert.ch'

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq 'facture-ragedevert-42.pdf'
    expect(attachment.content_type).to eq 'application/pdf'
  end

  specify '#overdue_notice_email' do
    template = MailTemplate.create!(title: 'invoice_overdue_notice')
    member = create(:member, emails: 'example@acp-admin.ch')
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: '24.03.2020',
      overdue_notices_count: 2,
      annual_fee: 62)

    mail = InvoiceMailer.with(
      template: template,
      member: member,
      invoice: invoice,
    ).overdue_notice_email

    expect(mail.subject).to eq('Rappel #2 de la facture #42 😬')
    expect(mail.to).to eq(['example@acp-admin.ch'])
    body = mail.html_part.body
    expect(body).to include('Le montant restant à payer est de: CHF 62')
    expect(body).to include('Accéder à ma page de membre')
    expect(body).to include('https://membres.ragedevert.ch/billing')
    expect(mail.from).to eq 'Rage de Vert info@ragedevert.ch'

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq 'facture-ragedevert-42.pdf'
    expect(attachment.content_type).to eq 'application/pdf'
  end
end
