# frozen_string_literal: true

require "test_helper"

class Member::SharesTest < ActiveSupport::TestCase
  test "validates desired_shares_number on public create" do
    org(annual_fee: 50, share_price: nil, shares_number: nil)
    member = build_member(desired_shares_number: 0)
    member.public_create = nil
    assert member.valid?
    member.public_create = true
    assert member.valid?

    org(annual_fee: nil, share_price: 100, shares_number: 1)
    member.public_create = nil
    assert member.valid?
    member.public_create = true
    assert_not member.valid?
    member.update(desired_shares_number: 1)
    assert member.valid?

    org(annual_fee: nil, share_price: 100, shares_number: 2)
    assert_not member.valid?
    member.update(desired_shares_number: 2)
    assert member.valid?

    basket_size = basket_sizes(:small)
    basket_size.update(shares_number: 3)
    member.update(waiting_basket_size_id: basket_size.id)
    assert_not member.valid?
    member.update(desired_shares_number: 3)
    assert member.valid?
  end

  test "shares_number includes existing and invoiced shares" do
    org(share_price: 100, shares_number: 1)
    member = members(:martha)
    member.update!(existing_shares_number: 2)

    assert_equal 2, member.shares_number
  end

  test "missing_shares_number when desired_shares_number only" do
    member = Member.new(desired_shares_number: 10, existing_shares_number: 0)
    assert_equal 10, member.missing_shares_number
  end

  test "missing_shares_number when matching existing_shares_number" do
    member = Member.new(desired_shares_number: 5, existing_shares_number: 5)
    assert_equal 0, member.missing_shares_number
  end

  test "missing_shares_number when more existing_shares_number" do
    member = Member.new(desired_shares_number: 5, existing_shares_number: 6)
    assert_equal 0, member.missing_shares_number
  end

  test "missing_shares_number when less existing_shares_number" do
    member = Member.new(desired_shares_number: 6, existing_shares_number: 4)
    assert_equal 2, member.missing_shares_number
  end

  test "missing_shares_number when requiring more membership shares" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:medium)
    basket_size.update!(shares_number: 2)
    member = members(:john)
    member.update(desired_shares_number: 1, existing_shares_number: 0)
    assert_equal 2, member.missing_shares_number
  end

  test "missing_shares_number when explicitly requiring more shares" do
    member = Member.new(desired_shares_number: 1, existing_shares_number: 0, required_shares_number: 3)
    assert_equal 3, member.missing_shares_number
  end

  test "missing_shares_number when explicitly requiring less shares and desired none" do
    member = Member.new(desired_shares_number: 0, existing_shares_number: 0, required_shares_number: 0)
    assert_equal 0, member.missing_shares_number
  end

  test "missing_shares_number when explicitly requiring less shares but still desired one" do
    member = Member.new(desired_shares_number: 1, existing_shares_number: 0, required_shares_number: 0)
    assert_equal 1, member.missing_shares_number
  end

  test "required_shares_number defaults to basket_size shares_number" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:medium)
    basket_size.update!(shares_number: 3)
    member = members(:john)

    assert_equal 3, member.required_shares_number
  end

  test "required_shares_number can be explicitly set" do
    member = Member.new(required_shares_number: 5, existing_shares_number: 0)
    assert_equal 5, member.required_shares_number
  end

  test "required_shares_number= accepts nil to clear explicit value" do
    member = Member.new(required_shares_number: 5, existing_shares_number: 0)
    member.required_shares_number = nil
    assert_equal 0, member.required_shares_number
  end

  test "handle_shares_change! sets state to support when shares exist and member is inactive" do
    org(share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:mary)
    member.update!(existing_shares_number: 1)

    member.handle_shares_change!

    assert_equal "support", member.state
  end

  test "handle_shares_change! sets state to inactive when no shares and member is support" do
    org(share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:martha)
    member.update_columns(state: "support", existing_shares_number: 0)

    member.handle_shares_change!

    assert_equal "inactive", member.state
  end

  test "changes inactive member state to support and back to inactive via invoice" do
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

  test "deactivate! removing negative number" do
    org(share_price: 100, shares_number: 1, annual_fee: nil)
    member = members(:martha)
    member.update(existing_shares_number: 2, required_shares_number: -2)
    assert_changes -> { member.state }, from: "inactive", to: "support" do
      member.update!(required_shares_number: 0)
    end
    assert_equal 0, member.desired_shares_number
    assert_equal 2, member.shares_number
  end
end
