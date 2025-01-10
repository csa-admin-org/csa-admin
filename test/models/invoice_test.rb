# frozen_string_literal: true

require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  def create_annual_fee_invoice(attrs = {})
    create_invoice({
      entity_type: "AnnualFee",
      annual_fee: 30
    }.merge(attrs))
  end

  def create_membership_invoice(attrs = {})
    create_invoice({
      entity: memberships(:john),
      membership_amount_fraction: 1,
      memberships_amount_description: "Annual billing"
    }.merge(attrs))
  end

  test "raises on amount=" do
    assert_raises(NoMethodError) { Invoice.new(amount: 1) }
  end

  test "raises on balance=" do
    assert_raises(NoMethodError) { Invoice.new(balance: 1) }
  end

  test "raises on memberships_amount=" do
    assert_raises(NoMethodError) { Invoice.new(memberships_amount: 1) }
  end

  test "raises on remaining_memberships_amount=" do
    assert_raises(NoMethodError) { Invoice.new(remaining_memberships_amount: 1) }
  end

  test "generates and sets pdf after creation" do
    enable_invoice_pdf

    invoice = create_annual_fee_invoice
    perform_enqueued_jobs

    assert invoice.pdf_file.attached?
    assert invoice.pdf_file.byte_size.positive?
  end

  test "sends email when send_email is true on creation" do
    mail_templates(:invoice_created)

    assert_no_difference 'InvoiceMailer.deliveries.size' do
      create_annual_fee_invoice(send_email: false)
      perform_enqueued_jobs
    end

    assert_difference 'InvoiceMailer.deliveries.size', 1 do
      create_annual_fee_invoice(send_email: true)
      perform_enqueued_jobs
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal "New invoice ##{Invoice.last.id}", mail.subject
  end

  test "does not send email when invoice is closed" do
    mail_templates(:invoice_created)
    create_payment(amount: 100)

    assert_no_difference 'InvoiceMailer.deliveries.size' do
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

  test "updates membership activity_participations_accepted" do
    membership = memberships(:john)
    invoice = Invoice.new(
      date: Date.today,
      member: members(:john),
      missing_activity_participations_count: 2,
      missing_activity_participations_fiscal_year: membership.fiscal_year,
      activity_price: 60)

    assert_changes -> { membership.reload.activity_participations_accepted }, from: 2, to: 4 do
      invoice.save!
      perform_enqueued_jobs
    end

    assert_changes -> { membership.reload.activity_participations_accepted }, from: 4, to: 2 do
      invoice.reload.destroy_or_cancel!
      perform_enqueued_jobs
    end
  end

  test "when annual fee only" do
    invoice = create_annual_fee_invoice

    assert invoice.annual_fee.present?
    assert_equal "AnnualFee", invoice.entity_type
    assert_nil invoice.memberships_amount
    assert_equal invoice.annual_fee, invoice.amount
  end

  test "default values for membership" do
    invoice = create_membership_invoice

    assert_nil invoice.annual_fee
    assert_equal "Membership", invoice.entity_type
    assert_equal 200, invoice.memberships_amount
    assert_equal 0, invoice.paid_memberships_amount
    assert_equal 200, invoice.remaining_memberships_amount
    assert_equal invoice.memberships_amount, invoice.amount
  end

  test "when paid_memberships_amount set" do
    invoice = create_membership_invoice(paid_memberships_amount: 40)

    assert_equal 160, invoice.memberships_amount
    assert_equal 40, invoice.paid_memberships_amount
    assert_equal 160, invoice.remaining_memberships_amount
    assert_equal invoice.memberships_amount, invoice.amount
  end

  test "when membership_amount_fraction set" do
    invoice = create_membership_invoice(membership_amount_fraction: 4)

    assert_equal 50, invoice.memberships_amount
    assert_equal 0, invoice.paid_memberships_amount
    assert_equal 200, invoice.remaining_memberships_amount
    assert_equal invoice.memberships_amount, invoice.amount
  end

  test "when annual_fee present as well" do
    invoice = create_membership_invoice(annual_fee: 30)

    assert invoice.annual_fee.present?
    assert_equal invoice.memberships_amount + invoice.annual_fee, invoice.amount
  end

  test "validates activity_price presence when missing_activity_participations_count is set" do
    invoice = Invoice.new(
      missing_activity_participations_count: 1,
      missing_activity_participations_fiscal_year: 2025,
      activity_price: nil)

    assert_not invoice.valid?
    assert_includes invoice.errors[:activity_price], "is not a number"
  end

  test "sets entity_type to ActivityParticipation with missing_activity_participations_count" do
    invoice = Invoice.new(
      missing_activity_participations_count: 2,
      missing_activity_participations_fiscal_year: 2025,
      activity_price: 21)
    invoice.validate

    assert_equal "ActivityParticipation", invoice.entity_type
    assert_equal 2, invoice.missing_activity_participations_count
    assert_equal 2025, invoice.missing_activity_participations_fiscal_year.year
    assert_equal 42, invoice.amount
  end

  test "automatically sets fiscal year and participation count" do
    part = activity_participations(:john_harvest)
    invoice = Invoice.new(entity: part)
    invoice.validate

    assert_equal part.member, invoice.member
    assert_equal 2, invoice.missing_activity_participations_count
    assert_equal FiscalYear.for(2024), invoice.missing_activity_participations_fiscal_year
  end

  test "sets entity_type to Share with shares_number" do
    org(share_price: 250, shares_number: 1)
    invoice = Invoice.new(shares_number: -2)

    assert_equal "Share", invoice.entity_type
    assert_equal -2, invoice.shares_number
    assert_equal -500, invoice.amount
  end

  test "sets items and round to five cents each item" do
    invoice = Invoice.new(
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10.11" },
        "1" => { description: "Cool free thing", amount: "0" },
        "2" => { description: "Cool expensive thing", amount: "32.33" }
      })

    assert_equal "Other", invoice.entity_type
    assert_equal 10.11, invoice.items.first.amount
    assert_equal 32.33, invoice.items.last.amount
    assert_equal 42.44, invoice.amount
  end

  test "accepts custom vat_rate" do
    org(vat_membership_rate: 7.7, vat_number: "XXX")
    invoice = Invoice.new(
      vat_rate: 2.5,
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_equal 2.5, invoice.vat_rate
    assert_equal 10, invoice.amount_with_vat
    assert_equal BigDecimal(9.76, 6), invoice.amount_without_vat
    assert_equal BigDecimal(0.24, 4), invoice.vat_amount
  end

  test "accepts no vat_rate" do
    org(vat_membership_rate: 7.7, vat_number: "XXX")

    invoice = Invoice.new(
      vat_rate: "",
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_nil invoice.vat_rate
    assert_equal 10, invoice.amount_with_vat
    assert_equal 10, invoice.amount_without_vat
    assert_nil invoice.vat_amount
  end

  test "set percentage (reduction)" do
    invoice = Invoice.new(
      amount_percentage: -10.1,
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_equal -10.1, invoice.amount_percentage
    assert_equal 10, invoice.amount_before_percentage
    assert_equal BigDecimal(8.99, 6), invoice.amount
  end

  test "set percentage (increase)" do
    invoice = Invoice.new(
      amount_percentage: 2.51,
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_equal 2.51, invoice.amount_percentage
    assert_equal 10, invoice.amount_before_percentage
    assert_equal BigDecimal(10.25, 6), invoice.amount
  end

  test "with vat" do
    org(vat_membership_rate: 7.7, vat_number: "XXX")

    invoice = Invoice.new(
      vat_rate: 2.5,
      amount_percentage: 10,
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_equal 10, invoice.amount_percentage
    assert_equal 10, invoice.amount_before_percentage
    assert_equal BigDecimal(11, 6), invoice.amount
    assert_equal 2.5, invoice.vat_rate
    assert_equal 11, invoice.amount_with_vat
    assert_equal BigDecimal(10.73, 6), invoice.amount_without_vat
    assert_equal BigDecimal(0.27, 4), invoice.vat_amount
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

    assert_no_difference 'InvoiceMailer.deliveries.size' do
      invoice.send!
      perform_enqueued_jobs
    end
  end

  test "does nothing when all member emails are suppressed" do
    mail_templates(:invoice_created)

    invoice = invoices(:annual_fee)
    invoice.member.active_emails.each { |email| suppress_email(email) }

    assert_equal [], invoice.member.reload.billing_emails
    assert_no_difference 'InvoiceMailer.deliveries.size' do
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

    assert_equal [], invoice.member.reload.billing_emails
    assert_no_difference 'InvoiceMailer.deliveries.size' do
      invoice.send!
      perform_enqueued_jobs
    end
    assert_nil invoice.reload.sent_at
  end

  test "does nothing when member has no email" do
    mail_templates(:invoice_created)

    invoice = invoices(:annual_fee)
    invoice.member.update!(emails: "")

    assert_no_difference 'InvoiceMailer.deliveries.size' do
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
        assert_no_difference 'InvoiceMailer.deliveries.size' do
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

    assert_difference 'InvoiceMailer.deliveries.size' do
      perform_enqueued_jobs { invoice.cancel! }
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal "Cancelled invoice ##{invoice.id}", mail.subject
    assert_includes mail.html_part.body.to_s, "Your invoice ##{invoice.id} from #{I18n.l(invoice.date)} has been cancelled."
  end

  test "does not send invoice_cancelled email when invoice is closed" do
    travel_to "2024-01-01"
    mail_templates(:invoice_cancelled).update!(active: true)
    invoice = invoices(:annual_fee)
    invoice.update!(state: "closed")

    assert_no_difference 'InvoiceMailer.deliveries.size' do
      perform_enqueued_jobs { invoice.cancel! }
    end
  end

  test "does not send email when template is not active" do
    mail_templates(:invoice_cancelled).update!(active: false)
    invoice = invoices(:annual_fee)

    assert_no_difference 'InvoiceMailer.deliveries.size' do
      perform_enqueued_jobs { invoice.cancel! }
    end
  end

  test "stamp the pdf" do
    invoice = invoices(:annual_fee)

    assert_changes -> { invoice.reload.stamped_at } do
      perform_enqueued_jobs { invoice.cancel! }
    end
  end

  test "does not set vat for non-membership invoices" do
    invoice = create_annual_fee_invoice
    assert_nil invoice.vat_amount
    assert_nil invoice.vat_rate
  end

  test "does not set vat when the organization has no VAT set" do
    org(vat_membership_rate: nil)

    invoice = create_membership_invoice
    assert_nil invoice.vat_rate
    assert_nil invoice.vat_amount
  end

  test "sets the vat_amount for membership invoice and the organization with rate set" do
    org(vat_membership_rate: 7.7, vat_number: "XXX")
    invoice = create_membership_invoice

    assert_equal 7.7, invoice.vat_rate
    assert_equal 200, invoice.amount_with_vat
    assert_equal BigDecimal(185.7, 6), invoice.amount_without_vat
    assert_equal BigDecimal(14.3, 4), invoice.vat_amount
  end

  test "sets the vat_amount for activity participation invoice" do
    org(vat_activity_rate: 5.5, vat_number: "XXX")
    invoice = Invoice.new(
      missing_activity_participations_count: 2,
      missing_activity_participations_fiscal_year: Current.fiscal_year,
      activity_price: 60)
    invoice.validate

    assert_equal 5.5, invoice.vat_rate
    assert_equal 120, invoice.amount_with_vat
    assert_equal BigDecimal(113.74, 6), invoice.amount_without_vat
    assert_equal BigDecimal(6.26, 4), invoice.vat_amount
  end

  test "sets the vat_amount for shop order invoice" do
    org(vat_shop_rate: 2.5, vat_number: "XXX")
    invoice = shop_orders(:john).invoice!

    assert_equal 2.5, invoice.vat_rate
    assert_equal 5, invoice.amount_with_vat
    assert_equal BigDecimal(4.88, 6), invoice.amount_without_vat
    assert_equal BigDecimal(0.12, 4), invoice.vat_amount
  end

  test "changes inactive member state to support and back to inactive" do
    org(share_price: 250, shares_number: 1)
    member = members(:mary)

    assert_changes -> { member.reload.state }, from: "inactive", to: "support" do
      create_invoice(member: member, shares_number: 1)
      perform_enqueued_jobs
    end

    assert_changes -> { member.reload.state }, from: "support", to: "inactive" do
      create_invoice(member: member, shares_number: -1)
      perform_enqueued_jobs
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
    first = Invoice.create!(entity: part, date: Date.today)
    latest = Invoice.create!(entity: part, date: Date.today)
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
    invoice.update!(state: "canceled", sent_at: Date.today)
    assert_not invoice.can_cancel?
  end

  test "can not cancel when shares type and closed" do
    org(share_price: 250, shares_number: 1)
    invoice = create_invoice(shares_number: 1)
    invoice.update!(state: "closed", sent_at: Date.today)
    assert_not invoice.can_cancel?
  end

  test "can cancel when shares type and open" do
    org(share_price: 250, shares_number: 1)
    invoice = create_invoice(shares_number: 1)
    invoice.update!(state: "open", sent_at: Date.today)
    assert invoice.can_cancel?
  end

  test "overpaid" do
    invoice = invoices(:annual_fee)
    create_payment(invoice: invoice, amount: 30)

    admin = admins(:master)
    admin.update!(notifications: %w[invoice_overpaid])

    assert_changes -> { invoice.reload.overpaid? }, to: true do
      create_payment(invoice: invoice, amount: 100)
    end

    assert_difference 'AdminMailer.deliveries.size' do
      perform_enqueued_jobs { invoice.send_overpaid_notification_to_admins! }
    end

    mail = AdminMailer.deliveries.last
    assert_equal "Overpaid invoice ##{invoice.id}", mail.subject
    assert_equal [ admin.email ], mail.to
    assert_includes mail.body.encoded, "Hello Thibaud,"
    assert_includes mail.body.encoded, "Martha"
  end

  test "does not send notification when not overpaid" do
    invoice = invoices(:annual_fee)

    admin = admins(:master)
    admin.update!(notifications: %w[invoice_overpaid])

    assert_no_changes -> { invoice.reload.overpaid_notification_sent_at } do
      invoice.send_overpaid_notification_to_admins!
    end
    assert_equal 0, AdminMailer.deliveries.size
  end

  test "does not send notification when already notified" do
    invoice = invoices(:annual_fee)
    create_payment(invoice: invoice, amount: 30)
    invoice.touch(:overpaid_notification_sent_at)

    admin = admins(:master)
    admin.update!(notifications: %w[invoice_overpaid])

    assert_no_difference 'AdminMailer.deliveries.size' do
      perform_enqueued_jobs { invoice.send_overpaid_notification_to_admins! }
    end
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

  test "set creator once processed" do
    admin = admins(:master)
    Current.session = create_session(admin)

    invoice = create_annual_fee_invoice

    assert invoice.processed?
    assert_equal admin, invoice.created_by
  end

  test "closing an invoice keep track of actor" do
    invoice = invoices(:annual_fee)
    assert_not invoice.closed?
    assert_nil invoice.closed_by

    admin = admins(:master)
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
    assert_equal [], invoice.previously_canceled_entity_invoice_ids
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

    assert_equal [], i1.previously_canceled_entity_invoice_ids
    assert_equal [ i2.id ], i3.previously_canceled_entity_invoice_ids
    assert_equal [ i4.id, i5.id ], i6.previously_canceled_entity_invoice_ids
  end
end
