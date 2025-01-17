# frozen_string_literal: true

require "test_helper"

class Billing::InvoicerShareTest < ActiveSupport::TestCase
  setup do
    org(share_price: 500, annual_fee: nil)
  end

  def invoice(member, **attrs)
    Billing::InvoicerShare.invoice(member, **attrs)
  end

  test "creates invoice for member with ongoing memberships that does not have the organization shares billed already" do
    travel_to "2024-01-01"
    basket_sizes(:large).update!(shares_number: 3)
    member = members(:jane)

    assert_difference -> { member.invoices.count }, 1 do
      assert_difference -> { member.reload.shares_number }, 3 do
        invoice(member)
      end
    end

    invoice = member.invoices.last
    assert_equal "Share", invoice.entity_type
    assert_equal 3, invoice.shares_number
    assert_equal Date.current, invoice.date
  end

  test "sends emails directly when the send_email attribute is set" do
    travel_to "2024-01-01"
    mail_templates(:invoice_created)
    basket_sizes(:large).update!(shares_number: 3)
    member = members(:jane)

    assert_difference -> { InvoiceMailer.deliveries.size }, 1 do
      perform_enqueued_jobs do
        invoice(member, send_email: true)
      end
    end

    mail = InvoiceMailer.deliveries.last
    assert_equal "New invoice ##{member.invoices.last.id}", mail.subject
  end

  test "creates invoice when the organization shares already partially billed" do
    travel_to "2024-01-01"
    basket_sizes(:large).update!(shares_number: 3)
    member = members(:jane)
    create_invoice(member: member, shares_number: 2)

    assert_difference -> { member.invoices.count }, 1 do
      assert_difference -> { member.shares_number }, 1 do
        invoice(member)
      end
    end
  end

  test "creates invoice when the organization shares desired and on support" do
    travel_to "2024-01-01"
    member = members(:martha)
    member.update!(desired_shares_number: 2)

    assert_difference -> { member.invoices.count }, 1 do
      assert_difference -> { member.shares_number }, 2 do
        invoice(member)
      end
    end
  end

  test "creates invoice when the organization shares desired and active with a shop depot" do
    travel_to "2024-01-01"
    member = members(:martha)
    member.update!(shop_depot_id: farm_id, desired_shares_number: 3)

    assert_difference -> { member.invoices.count }, 1 do
      assert_difference -> { member.shares_number }, 3 do
        invoice(member)
      end
    end
  end

  test "does nothing when the organization shares already billed" do
    travel_to "2024-01-01"
    member = members(:martha)
    member.update!(desired_shares_number: 2)
    create_invoice(member: member, shares_number: 2)

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "does nothing when the organization shares already exists prior to system use" do
    travel_to "2024-01-01"
    basket_sizes(:large).update!(shares_number: 3)
    member = members(:jane)
    member.update!(existing_shares_number: 3)

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "does nothing when inactive" do
    member = members(:mary)

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "ignore member in trial period" do
    travel_to "2024-01-01"
    basket_sizes(:large).update!(shares_number: 3)
    member = members(:jane)
    member.update_trial_baskets!

    assert_equal "2024-04-11", member.baskets.trial.last.delivery.date.to_s

    travel_to "2024-04-11"
    member.membership.update_baskets_counts!
    member.reload
    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end

    travel_to "2024-04-12"
    member.membership.update_baskets_counts!
    member.reload
    assert_difference -> { member.invoices.count }, 1 do
      invoice(member)
    end
  end
end
