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

  test "reports decimal prices as tags AppSignal keeps" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.send(:update_price_and_invoices_amount!)
    membership.update_column(:price, "-35.5")
    membership.reload
    expected_price = membership.computed_membership_price
    parts = {
      baskets_annual_price_change: membership.baskets_annual_price_change,
      basket_sizes_price: membership.basket_sizes_price,
      baskets_price_extra: membership.baskets_price_extra,
      basket_complements_price: membership.basket_complements_price,
      basket_complements_annual_price_change: membership.basket_complements_annual_price_change,
      depots_price: membership.depots_price,
      deliveries_price: membership.deliveries_price,
      activity_participations_annual_price_change: membership.activity_participations_annual_price_change
    }

    recorder = ErrorRecorder.new
    with_rails_error(recorder) do
      Checker::MembershipPrice.new(membership).check!
    end

    message, context = recorder.unexpected_errors.sole
    assert_equal "Membership price cache error", message
    assert_equal membership.id, context.fetch(:membership_id)
    assert_equal "-35.5", context.fetch(:price)
    assert_equal "200.0", context.fetch(:expected_price)
    assert_equal expected_price.to_d, BigDecimal(context.fetch(:expected_price))
    assert_equal "0.0", context.fetch(:baskets_annual_price_change)
    parts.each do |part, amount|
      assert_equal tag_value(amount), context.fetch(part), part.to_s
      refute_kind_of BigDecimal, context.fetch(part)
    end

    kept = appsignal_tags(context)
    context.each do |key, value|
      assert_equal value, kept.fetch(key)
    end
    assert_equal 200, membership.reload.price
  end

  private

  def tag_value(amount)
    return amount if amount.is_a?(Integer) || amount.nil?

    amount.to_d.to_s("F")
  end

  def appsignal_tags(tags)
    transaction = Appsignal::Transaction.allocate
    transaction.instance_variable_set(:@tags, tags)
    transaction.send(:sanitized_tags)
  end
end
