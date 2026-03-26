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

  test "ignore member in trial period spanning two fiscal years" do
    travel_to "2024-05-20"
    org(share_price: 500, trial_baskets_count: 4)
    basket_sizes(:small).update!(shares_number: 2)

    member = members(:mary)
    member.update_columns(trial_baskets_count: 4)

    # Membership 1: 3 baskets (May 20, May 27, Jun 3) — all trial
    m1 = create_membership(
      member: member,
      started_on: "2024-05-20",
      ended_on: "2024-12-31"
    )
    # Membership 2: 10 baskets (Apr 7 – Jun 9) — first one is trial
    m2 = create_membership(
      member: member,
      started_on: "2025-01-01",
      ended_on: "2025-12-31"
    )
    member.reload

    assert_equal 3, m1.trial_baskets_count
    assert_equal 1, m2.trial_baskets_count

    # m1's trial baskets are all past, but m2 still has a remaining trial basket
    travel_to "2024-06-04"
    m1.update_baskets_counts!
    m2.update_baskets_counts!
    member.reload

    assert_equal 0, m1.remaining_trial_baskets_count
    assert_equal 1, m2.remaining_trial_baskets_count

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end

    # Trial fully over after last trial basket (Apr 7, 2025) is delivered
    travel_to "2025-04-08"
    m1.update_baskets_counts!
    m2.update_baskets_counts!
    member.reload

    assert_equal 0, m2.remaining_trial_baskets_count

    assert_difference -> { member.invoices.count }, 1 do
      invoice(member)
    end
  end
end
