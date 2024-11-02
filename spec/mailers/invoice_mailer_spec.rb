# frozen_string_literal: true

require "rails_helper"

describe InvoiceMailer do
  specify "#created_email" do
    template = MailTemplate.find_by(title: "invoice_created")
    member = create(:member, emails: "example@csa-admin.org")
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: "24.03.2020",
      annual_fee: 62)

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    expect(mail.subject).to eq("Nouvelle facture #42")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    body = mail.html_part.body
    expect(body).to include("Voici votre nouvelle facture")
    expect(body).to include("Accéder à ma page de membre")
    expect(body).to include("https://membres.acme.test/billing")
    expect(mail.tag).to eq("invoice-created")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq "facture-acme-42.pdf"
    expect(attachment.content_type).to eq "application/pdf"
  end

  specify "#created_email (closed)" do
    template = MailTemplate.find_by(title: "invoice_created")
    member = create(:member, emails: "example@csa-admin.org")
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: "24.03.2020",
      annual_fee: 62)
    create(:payment, member: member, amount: 100)
    invoice.reload

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    expect(mail.subject).to eq("Nouvelle facture #42")
    body = mail.html_part.body
    expect(body).to include("En tenant compte des paiements précédents, cette facture est considérée comme payée et est envoyée uniquement à titre d'information.")
  end

  specify "#created_email (partially paid)" do
    template = MailTemplate.find_by(title: "invoice_created")
    member = create(:member, emails: "example@csa-admin.org")
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: "24.03.2020",
      annual_fee: 62)
    create(:payment, member: member, amount: 20)
    invoice.reload

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    expect(mail.subject).to eq("Nouvelle facture #42")
    body = mail.html_part.body
    expect(body).to include("En tenant compte des paiements précédents, le montant restant à payer est de: CHF 42.00")
  end

  specify "#created_email (Shop::Order)" do
    template = MailTemplate.find_by(title: "invoice_created")
    member = create(:member, emails: "example@csa-admin.org")
    order = create(:shop_order, :pending, id: 51235, member: member)
    invoice = order.invoice!

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    body = mail.html_part.body
    expect(body).to include(
      "Voici votre nouvelle facture, pour votre commande N° 51235, ")

    expect(mail.attachments.size).to eq 1
    expect(mail.attachments.first.content_type).to eq "application/pdf"
  end

  specify "#created_email (billing_email)" do
    template = MailTemplate.find_by(title: "invoice_created")
    member = create(:member,
      emails: "example@csa-admin.org",
      billing_email: "john@doe.com")
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: "24.03.2020",
      annual_fee: 62)

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    expect(mail.subject).to eq("Nouvelle facture #42")
    expect(mail.to).to eq([ "john@doe.com" ])
    expect(mail.tag).to eq("invoice-created")
    body = mail.html_part.body
    expect(body).to include("Voici votre nouvelle facture")
    expect(body).not_to include("Accéder à ma page de membre")
    expect(body).not_to include("https://membres.acme.test/billing")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq "facture-acme-42.pdf"
    expect(attachment.content_type).to eq "application/pdf"
  end

  specify "#cancelled_email" do
    template = MailTemplate.find_by(title: "invoice_cancelled")
    member = create(:member, emails: "example@csa-admin.org")
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: "24.03.2020",
      annual_fee: 62)

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).cancelled_email

    expect(mail.subject).to eq("Facture annulée #42")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("invoice-cancelled")
    body = mail.body
    expect(body)
      .to include "Votre facture ##{invoice.id} du #{I18n.l(invoice.date)} vient d'être annulée."
    expect(body).to include("Accéder à ma page de membre")
    expect(body).to include("https://membres.acme.test/billing")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"

    expect(mail.attachments.size).to be_zero
  end

  specify "#overdue_notice_email" do
    template = MailTemplate.find_by(title: "invoice_overdue_notice")
    member = create(:member, emails: "example@csa-admin.org")
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: "24.03.2020",
      overdue_notices_count: 2,
      annual_fee: 62)

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).overdue_notice_email

    expect(mail.subject).to eq("Rappel #2 de la facture #42 😬")
    expect(mail.to).to eq([ "example@csa-admin.org" ])
    expect(mail.tag).to eq("invoice-overdue-notice")
    body = mail.html_part.body
    expect(body).to include("Le montant restant à payer est de: CHF 62")
    expect(body).to include("Accéder à ma page de membre")
    expect(body).to include("https://membres.acme.test/billing")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq "facture-acme-42.pdf"
    expect(attachment.content_type).to eq "application/pdf"
  end

  specify "#overdue_notice_email (billing_email)" do
    template = MailTemplate.find_by(title: "invoice_overdue_notice")
    member = create(:member,
      emails: "example@csa-admin.org",
      billing_email: "john@doe.com")
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 42,
      date: "24.03.2020",
      overdue_notices_count: 2,
      annual_fee: 62)

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).overdue_notice_email

    expect(mail.subject).to eq("Rappel #2 de la facture #42 😬")
    expect(mail.to).to eq([ "john@doe.com" ])
    expect(mail.tag).to eq("invoice-overdue-notice")
    body = mail.html_part.body
    expect(body).to include("Le montant restant à payer est de: CHF 62")
    expect(body).not_to include("Accéder à ma page de membre")
    expect(body).not_to include("https://membres.acme.test/billing")
    expect(mail[:from].decoded).to eq "Rage de Vert <info@acme.test>"
    expect(mail[:message_stream].to_s).to eq "outbound"

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq "facture-acme-42.pdf"
    expect(attachment.content_type).to eq "application/pdf"
  end

  specify "sanitize html from subject" do
    template = MailTemplate.find_by(title: "invoice_overdue_notice")
    template.update!(subject: 'Rappel <strong>#{{ invoice.overdue_notices_count }}</strong> 😬')

    member = create(:member, name: "John Doe")
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      overdue_notices_count: 2)

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).overdue_notice_email

    expect(mail.subject).to eq("Rappel #2 😬")
  end
end
