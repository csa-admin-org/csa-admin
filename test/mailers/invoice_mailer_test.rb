# frozen_string_literal: true

require "test_helper"

class InvoiceMailerTest < ActionMailer::TestCase
  test "created_email" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    assert_equal "New invoice ##{invoice.id}", mail.subject
    assert_equal [ "support@annual.com" ], mail.to
    assert_equal "invoice-created", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.html_part.body.to_s
    assert_includes body, "Here is your new invoice"
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test/billing"

    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "invoice-acme-#{invoice.id}.pdf", attachment.filename
    assert_equal "application/pdf", attachment.content_type
  end

  test "created_email (closed)" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)
    invoice.state = "closed"

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    assert_equal "New invoice ##{invoice.id}", mail.subject
    body = mail.html_part.body.to_s
    assert_includes body, "Considering previous payments, this invoice is considered paid and is sent for informational purposes only."
  end

  test "created_email (partially paid)" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)
    Payment.create!(invoice: invoice, amount: 11, date: Date.yesterday)
    invoice.reload

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    assert_equal "New invoice ##{invoice.id}", mail.subject
    body = mail.html_part.body.to_s
    assert_includes body, "Considering previous payments, the remaining amount to be paid is: CHF 19.00"
  end

  test "created_email (with invoice attachments)" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)
    attachment = Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture("logo.png")),
      filename: "Our logo.png")
    invoice.update!(attachments: [ attachment ])

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    assert_equal "New invoice ##{invoice.id}", mail.subject
    body = mail.html_part.body.to_s
    assert_includes body, "Here is your new invoice"

    assert_equal 2, mail.attachments.size
    invoice_pdf = mail.attachments.first
    assert_equal "invoice-acme-#{invoice.id}.pdf", invoice_pdf.filename
    assert_equal "application/pdf", invoice_pdf.content_type
    attachment = mail.attachments.last
    assert_equal "Our logo.png", attachment.filename
    assert_equal "image/png", attachment.content_type
  end

  test "created_email SEPA membership (with invoice attachments)" do
    travel_to "2024-01-01"
    org(
      languages: [ "de" ],
      country_code: "DE",
      currency_code: "EUR",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    template = mail_templates(:invoice_created)
    member = members(:jane)
    member.update!(
      language: "de",
      iban: "DE21500500009876543210",
      sepa_mandate_id: "123456",
      sepa_mandate_signed_on: "2023-12-24")
    invoice = create_invoice(
      member: member,
      entity: memberships(:jane),
      memberships_amount_description: "Jährliche Rechnungsstellung")

    I18n.with_locale(:de) do
      mail = InvoiceMailer.with(
        template: template,
        invoice: invoice,
      ).created_email

      invoice_pdf = mail.attachments.first
      assert_equal "mitgliedsbestaetigung-acme-#{invoice.id}.pdf", invoice_pdf.filename
      assert_equal "application/pdf", invoice_pdf.content_type
    end
  end

  test "created_email (Shop::Order)" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    order = shop_orders(:john)
    invoice = order.invoice!

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    body = mail.html_part.body.to_s
    assert_includes body, "Here is your new invoice for your order number #{order.id}, "

    assert_equal 1, mail.attachments.size
    assert_equal "application/pdf", mail.attachments.first.content_type
  end

  test "created_email (Shop::Order with attachments)" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    order = shop_orders(:john)
    attachment = Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture("logo.png")),
      filename: "Our logo.png")
    order.update!(attachments: [ attachment ])
    invoice = order.invoice!

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    body = mail.html_part.body.to_s
    assert_includes body, "Here is your new invoice for your order number #{order.id}, "

    assert_equal 2, mail.attachments.size
    invoice_pdf = mail.attachments.first
    assert_equal "invoice-acme-#{invoice.id}.pdf", invoice_pdf.filename
    assert_equal "application/pdf", mail.attachments.first.content_type
    attachment = mail.attachments.last
    assert_equal "Our logo.png", attachment.filename
    assert_equal "image/png", attachment.content_type
  end

  test "created_email (billing_email)" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)
    invoice.member.billing_email = "info@accounting.com"

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).created_email

    assert_equal "New invoice ##{invoice.id}", mail.subject
    assert_equal [ "info@accounting.com" ], mail.to
    assert_equal "invoice-created", mail.tag
    body = mail.html_part.body.to_s
    assert_includes body, "Here is your new invoice"
    assert_not_includes body, "Access my member page"
    assert_not_includes body, "https://members.acme.test/billing"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "invoice-acme-#{invoice.id}.pdf", attachment.filename
    assert_equal "application/pdf", attachment.content_type
  end

  test "cancelled_email" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_cancelled)
    invoice = invoices(:annual_fee)

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).cancelled_email

    assert_equal "Cancelled invoice ##{invoice.id}", mail.subject
    assert_equal [ "support@annual.com" ], mail.to
    assert_equal "invoice-cancelled", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.body.to_s
    assert_includes body, "Your invoice ##{invoice.id} from #{I18n.l(invoice.date)} has been cancelled."
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test/billing"

    assert_equal 0, mail.attachments.size
  end

  test "overdue_notice_email" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_overdue_notice)
    invoice = invoices(:annual_fee)
    invoice.overdue_notices_count = 2

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).overdue_notice_email

    assert_equal "Overdue notice #2 for invoice ##{invoice.id} 😬", mail.subject
    assert_equal [ "support@annual.com" ], mail.to
    assert_equal "invoice-overdue-notice", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded

    body = mail.html_part.body.to_s
    assert_includes body, "The remaining amount to be paid is: CHF 30.00"
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test/billing"

    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "invoice-acme-#{invoice.id}.pdf", attachment.filename
    assert_equal "application/pdf", attachment.content_type
  end

  test "overdue_notice_email (billing_email)" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_overdue_notice)
    invoice = invoices(:annual_fee)
    invoice.overdue_notices_count = 2
    invoice.member.billing_email = "info@accounting.com"

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).overdue_notice_email

    assert_equal "Overdue notice #2 for invoice ##{invoice.id} 😬", mail.subject
    assert_equal [ "info@accounting.com" ], mail.to
    assert_equal "invoice-overdue-notice", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.html_part.body.to_s
    assert_includes body, "The remaining amount to be paid is: CHF 30.00"
    assert_not_includes body, "Access my member page"
    assert_not_includes body, "https://members.acme.test/billing"

    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "invoice-acme-#{invoice.id}.pdf", attachment.filename
    assert_equal "application/pdf", attachment.content_type
  end

  test "sanitize html from subject" do
    travel_to "2024-01-01"
    template = mail_templates(:invoice_overdue_notice)
    template.update!(subject: 'Reminder <strong>#{{ invoice.overdue_notices_count }}</strong> 😬')

    invoice = invoices(:annual_fee)
    invoice.overdue_notices_count = 2

    mail = InvoiceMailer.with(
      template: template,
      invoice: invoice,
    ).overdue_notice_email

    assert_equal "Reminder #2 😬", mail.subject
  end
end
