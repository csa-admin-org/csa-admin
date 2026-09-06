# frozen_string_literal: true

module Demo::Seeder::BiddingRounds
  extend ActiveSupport::Concern

  private

  # Solawi story for demo-de: a winter failed round, then a completed one that
  # writes pledged share prices onto current-year memberships. Skips open! /
  # complete! / fail! so we don't fan out emails during seed. Must run after
  # the seed transaction so Membership#price exists (after_commit).
  def seed_bidding_rounds!
    return unless germany?

    log "Seeding bidding rounds..."
    fy = Current.fiscal_year
    memberships = BiddingRound.new(fy_year: fy.year).eligible_memberships.to_a
    return if memberships.empty?

    failed_opened_on = fy.beginning_of_year + 7.days
    failed = create_open_bidding_round!(
      fy_year: fy.year,
      information_key: "bidding_round_failed_info",
      opened_on: failed_opened_on)
    seed_pledges!(failed, memberships, coverage: 0.45, factor_range: 0.55..0.95)
    close_bidding_round!(failed, "failed", failed_opened_on + 17.days)

    completed_opened_on = failed_opened_on + 24.days
    completed = create_open_bidding_round!(
      fy_year: fy.year,
      information_key: "bidding_round_completed_info",
      opened_on: completed_opened_on)
    seed_pledges!(completed, memberships, coverage: 0.9, factor_range: 0.8..1.25)
    close_bidding_round!(completed, "completed", completed_opened_on + 20.days)
    apply_completed_pledges!(completed)
  end

  def create_open_bidding_round!(fy_year:, information_key:, opened_on:)
    round = BiddingRound.create!(
      fy_year: fy_year,
      information_texts: {
        @org_language => Demo::Seeder::TRANSLATIONS.fetch(information_key).fetch(@org_language)
      })
    round.update!(state: "open")
    opened_at = opened_on.beginning_of_day
    round.update_columns(created_at: opened_at, updated_at: opened_at)
    round.audits.order(:id).last&.update_columns(created_at: opened_at)
    round
  end

  def seed_pledges!(round, memberships, coverage:, factor_range:)
    count = (memberships.size * coverage).round.clamp(1, memberships.size)
    opened_on = round.created_at.to_date
    memberships.sample(count).each do |membership|
      catalog = membership.basket_size.price
      min_price = catalog * Current.org.bidding_round_basket_size_price_min_percentage / 100.0
      max_price = catalog * (100 + Current.org.bidding_round_basket_size_price_max_percentage) / 100.0
      price = (catalog * rand(factor_range)).round(2).clamp(min_price, max_price)
      pledge = round.pledges.create!(membership: membership, basket_size_price: price)
      pledged_at = (opened_on + rand(0..10).days).beginning_of_day
      pledge.update_columns(created_at: pledged_at, updated_at: pledged_at)
    end
  end

  def apply_completed_pledges!(round)
    round.pledges.includes(:membership).find_each do |pledge|
      membership = pledge.membership
      membership.update!(
        basket_size_price: pledge.basket_size_price,
        new_config_from: membership.started_on)
    end
  end

  def close_bidding_round!(round, state, closed_on)
    round.update!(
      state: state,
      eligible_memberships_count: round.eligible_memberships_count,
      total_expected_value: round.total_expected_value,
      total_final_value: round.total_final_value)
    closed_at = closed_on.beginning_of_day
    round.update_columns(updated_at: closed_at)
    round.audits.order(:id).last&.update_columns(created_at: closed_at)
  end
end
