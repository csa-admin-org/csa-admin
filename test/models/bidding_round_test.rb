# frozen_string_literal: true

require "test_helper"

class BiddingRoundTest < ActiveSupport::TestCase
  def setup
    travel_to("2024-01-01")
  end

  test "has states" do
    bidding_round = BiddingRound.new
    assert_respond_to bidding_round, :draft?
    assert_respond_to bidding_round, :open?
    assert_respond_to bidding_round, :failed?
    assert_respond_to bidding_round, :completed?
  end

  test "defaults to draft state" do
    bidding_round = BiddingRound.new
    assert bidding_round.draft?
  end

  test "validates fiscal_year cannot be in the past" do
    bidding_round = BiddingRound.new(fy_year: 2023)
    assert_not bidding_round.valid?
    assert_includes bidding_round.errors[:fiscal_year], "is invalid"
  end

  test "validates fiscal_year can be current year" do
    bidding_rounds(:draft_2024).delete
    bidding_round = BiddingRound.new(fy_year: 2024)
    assert bidding_round.valid?
  end

  test "validates fiscal_year can be future year" do
    bidding_rounds(:draft_2024).delete
    bidding_round = BiddingRound.new(fy_year: 2025)
    assert bidding_round.valid?
  end

  test "validates only one draft bidding round" do
    bidding_round = BiddingRound.new(fy_year: 2025)

    assert_not bidding_round.valid?
    assert_includes bidding_round.errors[:fiscal_year], "is invalid"
  end

  test "validates only one open bidding round" do
    bidding_round = BiddingRound.new(fy_year: 2025, state: "open")

    assert_not bidding_round.valid?
    assert_includes bidding_round.errors[:fiscal_year], "is invalid"
  end

  test "validates memberships must exist for fiscal year" do
    bidding_rounds(:draft_2024).delete
    bidding_round = BiddingRound.new(fy_year: 2026)

    assert_equal 0, bidding_round.eligible_memberships_count
    assert_not bidding_round.valid?
    assert_includes bidding_round.errors[:fiscal_year], "is invalid"
  end

  test "title includes fiscal year and number" do
    assert_equal "Bidding Round 2024 #2", bidding_rounds(:draft_2024).title
    assert_equal "Bidding Round 2024 #1", bidding_rounds(:open_2024).title
  end

  test "number is based on creation order within fiscal year" do
    BiddingRound.delete_all
    first_2024 = BiddingRound.create!(fy_year: 2024, state: "completed")
    first_2025 = BiddingRound.create!(fy_year: 2025, state: "open")
    second_2024 = BiddingRound.create!(fy_year: 2024)

    assert_equal 1, first_2024.number
    assert_equal 1, first_2025.number
    assert_equal 2, second_2024.number
  end

  test "total_expected_value calculates from memberships" do
    bidding_round = bidding_rounds(:open_2024)
    assert_equal 34 + 10 * 20 + 19 + 10 * 38, bidding_round.total_expected_value
  end

  test "total_pledged_value calculates from pledges" do
    bidding_round = bidding_rounds(:open_2024)
    BiddingRound::Pledge.create!(
      bidding_round: bidding_round,
      membership: memberships(:jane),
      basket_size_price: 31.0)

    assert_equal 10 * (31 + 8), bidding_round.total_pledged_value
  end

  test "total_pledged_percentage" do
    bidding_round = bidding_rounds(:open_2024)
    BiddingRound::Pledge.create!(
      bidding_round: bidding_round,
      membership: memberships(:jane),
      basket_size_price: 31.0)

    assert_equal 61.61, bidding_round.total_pledged_percentage
  end

  test "missing_pledges_count" do
    bidding_round = bidding_rounds(:open_2024)

    assert_changes -> { bidding_round.missing_pledges_count }, from: 4, to: 3 do
      BiddingRound::Pledge.create!(
        bidding_round: bidding_round,
        membership: memberships(:jane),
        basket_size_price: 31.0)
    end
  end

  test "can_create?" do
    BiddingRound.delete_all

    assert BiddingRound.can_create?

    BiddingRound.create!(fy_year: 2025, state: "draft")
    assert_not BiddingRound.can_create?
  end

  test "can_update?" do
    assert bidding_rounds(:draft_2024).can_update?

    bidding_round = bidding_rounds(:open_2024)
    assert bidding_round.can_update?

    bidding_round.update!(state: "completed")
    assert_not bidding_round.can_update?

    bidding_round.update!(state: "failed")
    assert_not bidding_round.can_update?
  end

  test "can_open?" do
    BiddingRound.delete_all

    bidding_round = BiddingRound.new(fy_year: 2025)
    assert bidding_round.can_open?

    bidding_round.update!(state: "completed")
    assert_not bidding_round.can_open?

    bidding_round.update!(state: "failed")
    assert_not bidding_round.can_open?

    BiddingRound.create!(fy_year: 2025, state: "open")
    assert_not bidding_round.can_open?

    bidding_round = BiddingRound.new(fy_year: 2026)
    assert_not bidding_round.can_open?
  end

  test "can_complete? / can_fail?" do
    BiddingRound.delete_all

    bidding_round = BiddingRound.new(fy_year: 2025, state: "draft")
    assert_not bidding_round.can_complete?
    assert_not bidding_round.can_fail?

    bidding_round = BiddingRound.new(fy_year: 2025, state: "open")
    assert bidding_round.can_complete?
    assert bidding_round.can_fail?

    bidding_round = BiddingRound.new(fy_year: 2025, state: "completed")
    assert_not bidding_round.can_complete?
    assert_not bidding_round.can_fail?

    bidding_round = BiddingRound.new(fy_year: 2025, state: "failed")
    assert_not bidding_round.can_complete?
    assert_not bidding_round.can_fail?
  end

  test "open!" do
    mail_templates(:bidding_round_opened)

    bidding_rounds(:open_2024).delete
    bidding_round = bidding_rounds(:draft_2024)

    assert_changes -> { bidding_round.state }, from: "draft", to: "open" do
      bidding_round.open!
    end

    assert_difference "BiddingRoundMailer.deliveries.size", 4 do
      perform_enqueued_jobs
    end
    mail = BiddingRoundMailer.deliveries.last
    assert_equal "Bidding round #2 is open", mail.subject
  end

  test "complete!" do
    mail_templates(:bidding_round_completed)

    bidding_round = bidding_rounds(:open_2024)
    membership = memberships(:jane)
    BiddingRound::Pledge.create!(
      bidding_round: bidding_round,
      membership: memberships(:jane),
      basket_size_price: 31.0)

    assert_changes -> { bidding_round.state }, from: "open", to: "completed" do
      assert_changes -> { membership.reload.basket_size_price }, from: 30, to: 31 do
        assert_difference "BiddingRoundMailer.deliveries.size", 4 do
          perform_enqueued_jobs do
            bidding_round.complete!
          end
        end
      end
    end
    assert_equal [ 31 ], membership.baskets.pluck(:basket_size_price).uniq
    mail = BiddingRoundMailer.deliveries.last
    assert_equal "Bidding round #1 completed 🎉", mail.subject
  end

  test "fail! changes state to failed" do
    mail_templates(:bidding_round_failed)

    bidding_round = bidding_rounds(:open_2024)
    membership = memberships(:jane)
    BiddingRound::Pledge.create!(
      bidding_round: bidding_round,
      membership: memberships(:jane),
      basket_size_price: 31.0)

    assert_changes -> { bidding_round.state }, from: "open", to: "failed" do
      assert_no_changes -> { membership.reload.basket_size_price }, from: 30 do
        bidding_round.fail!
      end
    end
    assert_equal [ 30 ], membership.baskets.pluck(:basket_size_price).uniq

    assert_difference "BiddingRoundMailer.deliveries.size", 4 do
      perform_enqueued_jobs
    end
    mail = BiddingRoundMailer.deliveries.last
    assert_equal "Bidding round #1 failed 😬", mail.subject
  end
end
