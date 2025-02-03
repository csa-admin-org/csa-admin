# frozen_string_literal: true

require "test_helper"

class InvoiceOverdueNoticeTest < ActiveSupport::TestCase
  def setup
    mail_templates(:invoice_overdue_notice)
  end

  def deliver(invoice)
    InvoiceOverdueNotice.deliver(invoice)
    perform_enqueued_jobs
    perform_enqueued_jobs
  end

  test "sends invoice overdue_notice email" do
    invoice = invoices(:annual_fee)
    invoice.update!(sent_at: 40.days.ago)

    assert_difference -> { invoice.reload.overdue_notices_count }, 1 do
      assert_changes -> { invoice.reload.overdue_notice_sent_at }, from: nil do
        deliver(invoice)
      end
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal "Overdue notice #1 for invoice ##{invoice.id} 😬", mail.subject
  end

  test "regenerate invoice PDF email" do
    enable_invoice_pdf
    invoice = invoices(:annual_fee)
    invoice.update!(sent_at: 40.days.ago)

    assert_difference -> { InvoiceMailer.deliveries.size }, 1 do
      assert_changes -> { invoice.pdf_file.download } do
        deliver(invoice)
      end
    end
  end

  test "only send overdue notice when invoice is open" do
    invoice = invoices(:other_closed)

    assert invoice.closed?
    assert_no_difference -> { InvoiceMailer.deliveries.size } do
      deliver(invoice)
    end
  end

  test "skip overdue notice when SEPA invoice" do
    invoice = invoices(:annual_fee)
    org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    invoice.update!(sepa_metadata: { iban: "CH9300762011623852957" })

    assert invoice.open?
    assert invoice.sepa?
    assert_no_difference -> { InvoiceMailer.deliveries.size } do
      deliver(invoice)
    end
  end

  test "does not send overdue notice when member emails is empty" do
    invoice = invoices(:annual_fee)
    invoice.update!(sent_at: 40.days.ago)
    invoice.member.update!(emails: "")

    assert_no_difference -> { InvoiceMailer.deliveries.size } do
      deliver(invoice)
    end
  end

  test "sends invoice overdue_notice to billing email" do
    invoice = invoices(:annual_fee)
    invoice.update!(sent_at: 40.days.ago)
    invoice.member.update!(emails: "", billing_email: "john@doe.com")

    assert_difference -> { InvoiceMailer.deliveries.size }, 1 do
      deliver(invoice)
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal [ "john@doe.com" ], mail.to
  end

  test "sends invoice overdue_notice to billing email only" do
    invoice = invoices(:annual_fee)
    invoice.update!(sent_at: 40.days.ago)
    invoice.member.update!(emails: "emma@doe.com", billing_email: "john@doe.com")

    assert_difference -> { InvoiceMailer.deliveries.size }, 1 do
      deliver(invoice)
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal [ "john@doe.com" ], mail.to
  end

  test "only send first overdue notice after 35 days" do
    invoice = invoices(:annual_fee)
    invoice.update!(sent_at: 34.days.ago)

    assert_no_difference -> { InvoiceMailer.deliveries.size } do
      deliver(invoice)
    end
  end

  test "only send second overdue notice after 35 days first one" do
    invoice = invoices(:annual_fee)
    invoice.update!(overdue_notices_count: 1, overdue_notice_sent_at: 34.days.ago)

    assert_no_difference -> { InvoiceMailer.deliveries.size } do
      deliver(invoice)
    end
  end

  test "sends second overdue notice after 35 days first one" do
    invoice = invoices(:annual_fee)
    invoice.update!(overdue_notices_count: 1, overdue_notice_sent_at: 35.days.ago)

    assert_difference -> { InvoiceMailer.deliveries.size }, 1 do
      deliver(invoice)
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal "Overdue notice #2 for invoice ##{invoice.id} 😬", mail.subject
    assert_equal 2, invoice.reload.overdue_notices_count
  end

  test "sends invoice_third_overdue_notice admin notification on third notice" do
    admin = admins(:master)
    admin.update!(notifications: [ "invoice_third_overdue_notice" ])

    invoice = invoices(:annual_fee)
    invoice.update!(overdue_notices_count: 2, overdue_notice_sent_at: 35.days.ago)

    assert_difference -> { ApplicationMailer.deliveries.size }, 2 do
      deliver(invoice)
    end

    mail = InvoiceMailer.deliveries.first
    assert_equal "Overdue notice #3 for invoice ##{invoice.id} 😬", mail.subject
    assert_equal 3, invoice.reload.overdue_notices_count

    mail = AdminMailer.deliveries.last
    assert_equal "Invoice ##{invoice.id}, 3rd reminder sent", mail.subject
    assert_equal [ admin.email ], mail.to
    assert_includes mail.html_part.body.to_s, admin.name
  end
end
