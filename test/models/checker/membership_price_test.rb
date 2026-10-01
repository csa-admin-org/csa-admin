# frozen_string_literal: true

require "test_helper"

class Checker::MembershipPriceTest < ActiveSupport::TestCase
  test "heals a stale price cache after reporting" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.send(:update_price_and_invoices_amount!)
    membership.update_column(:price, 0)

    Rails.error.stub(:unexpected, nil) do
      Checker::MembershipPrice.new(membership.reload).check!
    end

    assert_equal 200, membership.reload.price
  end

  test "does not report when the cache matches billable baskets" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.send(:update_price_and_invoices_amount!)

    reported = false
    Rails.error.stub(:unexpected, ->(*) { reported = true }) do
      Checker::MembershipPrice.new(membership.reload).check!
    end

    assert_not reported
  end
end
