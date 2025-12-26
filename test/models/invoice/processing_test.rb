# frozen_string_literal: true

require "test_helper"

class Invoice::ProcessingTest < ActiveSupport::TestCase
  test "generates and sets pdf after creation" do
    enable_invoice_pdf

    invoice = create_annual_fee_invoice
    perform_enqueued_jobs

    assert invoice.pdf_file.attached?
    assert invoice.pdf_file.byte_size.positive?
  end

  test "sends email when send_email is true on creation" do
    mail_templates(:invoice_created)

    assert_no_difference "InvoiceMailer.deliveries.size" do
      create_annual_fee_invoice(send_email: false)
      perform_enqueued_jobs
    end

    assert_difference "InvoiceMailer.deliveries.size", 1 do
      create_annual_fee_invoice(send_email: true)
      perform_enqueued_jobs
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal "New invoice ##{Invoice.last.id}", mail.subject
  end

  test "does not send email when invoice is closed" do
    mail_templates(:invoice_created)
    create_payment(amount: 100)

    assert_no_difference "InvoiceMailer.deliveries.size" do
      create_annual_fee_invoice(send_email: true)
      perform_enqueued_jobs
    end
  end

  test "closes invoice before sending email" do
    mail_templates(:invoice_created)
    org(send_closed_invoice: true)
    create_payment(amount: 100)

    invoice = create_annual_fee_invoice(send_email: true)
    perform_enqueued_jobs

    mail = InvoiceMailer.deliveries.last
    assert_equal "New invoice ##{invoice.id}", mail.subject
    assert_includes mail.html_part.body.to_s, "this invoice is considered paid"
  end

  test "touches sent_at" do
    invoice = invoices(:annual_fee)
    assert_changes -> { invoice.sent_at } do
      invoice.send!
    end
  end

  test "keeps invoice as open" do
    invoice = invoices(:annual_fee)
    assert_no_changes -> { invoice.state }, from: "open" do
      invoice.send!
    end
  end

  test "does nothing when already sent" do
    mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)
    invoice.touch(:sent_at)

    assert_no_difference "InvoiceMailer.deliveries.size" do
      invoice.send!
      perform_enqueued_jobs
    end
  end

  test "does nothing when all member emails are suppressed" do
    mail_templates(:invoice_created)

    invoice = invoices(:annual_fee)
    invoice.member.active_emails.each { |email| suppress_email(email) }

    assert_empty invoice.member.reload.billing_emails
    assert_no_difference "InvoiceMailer.deliveries.size" do
      invoice.send!
      perform_enqueued_jobs
    end
    assert_nil invoice.reload.sent_at
  end

  test "does nothing when member billing email is suppressed" do
    mail_templates(:invoice_created)

    invoice = invoices(:annual_fee)
    invoice.member.update!(billing_email: "john@doe.com")
    suppress_email("john@doe.com")

    assert_empty invoice.member.reload.billing_emails
    assert_no_difference "InvoiceMailer.deliveries.size" do
      invoice.send!
      perform_enqueued_jobs
    end
    assert_nil invoice.reload.sent_at
  end

  test "does nothing when member has no email" do
    mail_templates(:invoice_created)

    invoice = invoices(:annual_fee)
    invoice.member.update!(emails: "")

    assert_no_difference "InvoiceMailer.deliveries.size" do
      invoice.send!
      perform_enqueued_jobs
    end
    assert_nil invoice.reload.sent_at
  end

  test "stores sender" do
    admin = admins(:super)
    Current.session = create_session(admin)

    invoice = invoices(:annual_fee)
    invoice.send!

    assert_equal admin, invoice.sent_by
  end

  test "mark_as_sent!" do
    mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)
    admin = admins(:super)
    Current.session = create_session(admin)

    assert_no_changes -> { invoice.state }, from: "open" do
      assert_changes -> { invoice.sent_at }, from: nil do
        assert_no_difference "InvoiceMailer.deliveries.size" do
          invoice.mark_as_sent!
          perform_enqueued_jobs
        end
      end
    end
    assert_equal admin, invoice.sent_by
  end

  test "cancel!" do
    invoice = invoices(:annual_fee)
    admin = admins(:super)
    Current.session = create_session(admin)

    assert_changes -> { invoice.state }, to: "canceled" do
      invoice.cancel!
    end
    assert_equal admin, invoice.canceled_by
  end

  test "send invoice_cancelled when the invoice was open" do
    mail_templates(:invoice_cancelled).update!(active: true)
    invoice = invoices(:annual_fee)

    assert_difference "InvoiceMailer.deliveries.size" do
      perform_enqueued_jobs { invoice.cancel! }
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal "Cancelled invoice ##{invoice.id}", mail.subject
    assert_includes mail.html_part.body.to_s, "Your invoice ##{invoice.id} from #{I18n.l(invoice.date)} has been cancelled."
  end

  test "does not send invoice_cancelled email when member has no billing emails" do
    mail_templates(:invoice_cancelled).update!(active: true)
    invoice = invoices(:annual_fee)
    invoice.member.update!(emails: "", billing_email: "")

    assert_no_difference "InvoiceMailer.deliveries.size" do
      perform_enqueued_jobs { invoice.cancel! }
    end
  end

  test "does not send invoice_cancelled email when invoice is closed" do
    travel_to "2024-01-01"
    mail_templates(:invoice_cancelled).update!(active: true)
    invoice = invoices(:annual_fee)
    invoice.update!(state: "closed")

    assert_no_difference "InvoiceMailer.deliveries.size" do
      perform_enqueued_jobs { invoice.cancel! }
    end
  end

  test "does not send email when template is not active" do
    mail_templates(:invoice_cancelled).update!(active: false)
    invoice = invoices(:annual_fee)

    assert_no_difference "InvoiceMailer.deliveries.size" do
      perform_enqueued_jobs { invoice.cancel! }
    end
  end

  test "stamp the pdf" do
    invoice = invoices(:annual_fee)

    assert_changes -> { invoice.reload.stamped_at } do
      perform_enqueued_jobs { invoice.cancel! }
    end
  end

  test "can destroy only if latest invoice id/number" do
    invoice = create_annual_fee_invoice
    assert invoice.can_destroy?

    new_invoice = create_annual_fee_invoice
    assert_not invoice.can_destroy?
    assert new_invoice.can_destroy?
  end

  test "can not destroy not sent invoice with payments" do
    invoice = create_annual_fee_invoice
    create_payment(invoice: invoice, amount: invoice.amount)
    assert_not invoice.can_destroy?
  end

  test "can cancel without entity id and current year" do
    travel_to "2024-01-01"
    invoice = invoices(:annual_fee)
    invoice.update!(state: "closed")

    assert invoice.can_cancel?
  end

  test "can cancel with entity id, only latest" do
    part = activity_participations(:john_harvest)
    first = Invoice.create!(entity: part, date: Date.current)
    latest = Invoice.create!(entity: part, date: Date.current)
    create_annual_fee_invoice
    perform_enqueued_jobs

    assert_not first.reload.can_cancel?
    assert latest.reload.can_cancel?
  end

  test "can not cancel when not current year but closed" do
    invoice = invoices(:annual_fee)
    invoice.update!(state: "closed", date: 13.months.ago)
    assert_not invoice.can_cancel?
  end

  test "can cancel last year activity participation invoice" do
    travel_to "2024-01-01"
    invoice = Invoice.create!(
      entity: activity_participations(:john_harvest),
      date: Date.current)
    perform_enqueued_jobs
    invoice.update!(state: "closed")
    create_annual_fee_invoice # no more last invoice

    travel_to "2025-01-01"
    assert invoice.can_cancel?
  end

  test "can cancel when not current year, closed, but membership current year" do
    travel_to "2024-01-01"
    invoice = invoices(:bob_membership)
    invoice.update!(state: "closed", date: 13.months.ago)
    assert invoice.can_cancel?
  end

  test "can cancel when not current year but open" do
    invoice = invoices(:annual_fee)
    invoice.update!(state: "open", date: 13.months.ago)
    assert invoice.can_cancel?
  end

  test "can not cancel when can be destroyed" do
    invoice = create_annual_fee_invoice
    assert invoice.can_destroy?
    assert_not invoice.can_cancel?
  end

  test "can not cancel when processing" do
    invoice = invoices(:annual_fee)
    invoice.update!(state: "processing")
    assert_not invoice.can_cancel?
  end

  test "can not cancel when already canceled" do
    invoice = invoices(:annual_fee)
    invoice.update!(state: "canceled", sent_at: Date.current)
    assert_not invoice.can_cancel?
  end

  test "can not cancel when shares type and closed" do
    org(share_price: 250, shares_number: 1)
    invoice = create_invoice(shares_number: 1)
    invoice.update!(state: "closed", sent_at: Date.current)
    assert_not invoice.can_cancel?
  end

  test "can cancel when shares type and open" do
    org(share_price: 250, shares_number: 1)
    invoice = create_invoice(shares_number: 1)
    invoice.update!(state: "open", sent_at: Date.current)
    assert invoice.can_cancel?
  end

  test "redistribute payments after destroy" do
    invoice1 = invoices(:annual_fee)
    invoice2 = create_annual_fee_invoice(member: invoice1.member)
    create_payment(member: invoice1.member, amount: 45)
    perform_enqueued_jobs

    assert invoice1.reload.closed?
    assert_changes -> { invoice1.reload.paid_amount }, from: 30, to: 45 do
      invoice2.destroy!
    end
  end

  test "document_name and pdf_filename" do
    invoice = invoices(:annual_fee)
    assert_equal "Invoice", invoice.document_name
    assert_equal "invoice-acme-#{invoice.id}.pdf", invoice.pdf_filename

    Current.org.update!(invoice_document_name: "Receipt")
    assert_equal "Receipt", invoice.document_name
    assert_equal "receipt-acme-#{invoice.id}.pdf", invoice.pdf_filename
  end

  test "set creator once processed" do
    admin = admins(:ultra)
    Current.session = create_session(admin)

    invoice = create_annual_fee_invoice

    assert invoice.processed?
    assert_equal admin, invoice.created_by
  end

  test "closing an invoice keep track of actor" do
    invoice = invoices(:annual_fee)
    assert_not invoice.closed?
    assert_nil invoice.closed_by

    admin = admins(:ultra)
    Current.session = create_session(admin)

    create_payment(invoice: invoice, amount: 30)

    invoice.reload
    assert_equal admin, invoice.closed_by
    assert_equal invoice.audits.last.created_at, invoice.closed_at
  end

  test "destroy is resetting the pk sequence" do
    create_annual_fee_invoice
    invoice = create_annual_fee_invoice
    current_id = invoice.id
    invoice.destroy!

    new_invoice = create_annual_fee_invoice
    assert_equal current_id, new_invoice.id
  end

  test "destroy only latest invoice" do
    invoice = invoices(:annual_fee)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      invoice.destroy!
    end
  end

  test "previously_canceled_entity_invoice_ids when no entity" do
    invoice = invoices(:annual_fee)
    assert_empty invoice.previously_canceled_entity_invoice_ids
  end

  test "previously_canceled_entity_invoice_ids with one previous cancel invoiced" do
    travel_to "2024-01-01"
    part = activity_participations(:john_harvest)
    i1 = create_invoice(entity: part)
    i2 = create_invoice(entity: part)
    i3 = create_invoice(entity: part)
    i4 = create_invoice(entity: part)
    i5 = create_invoice(entity: part)
    i6 = create_invoice(entity: part)
    i2.update_columns(state: "canceled")
    i4.update_columns(state: "canceled")
    i5.update_columns(state: "canceled")

    assert_empty i1.previously_canceled_entity_invoice_ids
    assert_equal [ i2.id ], i3.previously_canceled_entity_invoice_ids
    assert_equal [ i4.id, i5.id ], i6.previously_canceled_entity_invoice_ids
  end
end
