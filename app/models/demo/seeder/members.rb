# frozen_string_literal: true

module Demo::Seeder::Members
  extend ActiveSupport::Concern

  private

  def seed_members!
    log "Seeding members..."
    @founding_members = create_members!(Demo::Seeder::FOUNDING_MEMBERS_COUNT, state: "active", trial_baskets_count: 0)
    @year_minus_one_joiners = create_members!(Demo::Seeder::YEAR_MINUS_ONE_JOINERS_COUNT, state: "active", trial_baskets_count: 0)
    @current_year_joiners = create_members!(Demo::Seeder::CURRENT_YEAR_JOINERS_COUNT, state: "active", trial_baskets_count: 0)
    @year_minus_two_churned = create_members!(Demo::Seeder::YEAR_MINUS_TWO_CHURNED_COUNT, state: "inactive", trial_baskets_count: 0)
    @year_minus_one_churned = create_members!(Demo::Seeder::YEAR_MINUS_ONE_CHURNED_COUNT, state: "inactive", trial_baskets_count: 0)
    @active_members = @founding_members + @year_minus_one_joiners + @current_year_joiners
    Demo::Seeder::TRIAL_MEMBERS_COUNT.times { @active_members << create_trial_member! }
    Demo::Seeder::WAITING_MEMBERS_COUNT.times { create_waiting_member! }
    Demo::Seeder::SUPPORT_MEMBERS_COUNT.times { create_support_member! }
    Demo::Seeder::PENDING_MEMBERS_COUNT.times { create_pending_member! }
    seed_membership_history!
  end

  def create_members!(count, **attrs)
    Array.new(count) { create_member!(**attrs) }
  end

  def create_trial_member!
    member = create_member!(state: "active")
    create_membership!(member, late_start: true)
    member
  end

  def create_waiting_member!
    create_member!(
      state: "waiting",
      waiting_started_at: rand(30..90).days.ago,
      waiting_basket_size: [ @small, @medium, @large ].sample,
      waiting_depot: @all_depots.sample,
      waiting_delivery_cycle: [ @weekly_cycle, @biweekly_cycle ].sample)
  end

  def create_support_member!
    create_member!(state: "support", annual_fee: Current.org.annual_fee)
  end

  def create_pending_member!
    create_member!(
      state: "pending",
      waiting_basket_size: [ @small, @medium ].sample,
      waiting_depot: [ @farm_depot, @market_depot ].sample,
      waiting_delivery_cycle: @weekly_cycle)
  end

  def create_member!(state:, **attrs)
    name = "#{Faker::Name.unique.first_name} #{Faker::Name.unique.last_name}"
    email = Faker::Internet.unique.email(name: name, domain: Demo::Seeder::EMAIL_DOMAINS.sample)
    phone_prefix = germany? ? "+49" : "+41"
    sepa_attrs = germany_sepa_attrs
    member = Member.create!(
      name: name,
      emails: email,
      phones: "#{phone_prefix} #{rand(70..79)} #{rand(100..999)} #{rand(10..99)} #{rand(10..99)}",
      street: Faker::Address.unique.street_address,
      zip: Faker::Address.unique.zip,
      city: Faker::Address.unique.city,
      country_code: Current.org.country_code,
      language: Current.org.languages.sample,
      state: state,
      annual_fee: Current.org.annual_fee,
      **attrs)
    create_member_sepa_mandate!(member, sepa_attrs) if sepa_attrs
    member
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create member: #{e.message}")
    retry
  end

  def germany_sepa_attrs
    return unless germany? && rand < 0.5

    {
      iban: Faker::Bank.iban(country_code: "de"),
      umr: SecureRandom.alphanumeric(12).upcase,
      signed_on: Date.current - rand(30..365).days
    }
  end

  def create_member_sepa_mandate!(member, sepa_attrs)
    member.sepa_mandates.create!(
      iban: sepa_attrs[:iban],
      umr: sepa_attrs[:umr],
      signed_on: sepa_attrs[:signed_on],
      source: "admin")
  end

  def seed_membership_history!
    fy2, fy1, fy0 = seed_fiscal_years
    founding_fy2 = @founding_members.map { |member| create_membership!(member, fiscal_year: fy2) }
    @year_minus_two_churned.each_with_index do |member, index|
      create_membership!(member, fiscal_year: fy2, early_exit: index < Demo::Seeder::EARLY_EXITS_PER_CHURN_YEAR)
    end
    founding_fy1 = @founding_members.zip(founding_fy2).map { |member, previous|
      create_membership!(member, fiscal_year: fy1, previous: previous)
    }
    joiners_fy1 = @year_minus_one_joiners.map { |member|
      create_membership!(member, fiscal_year: fy1, late_start: rand < 0.3)
    }
    @year_minus_one_churned.each_with_index do |member, index|
      create_membership!(member, fiscal_year: fy1, early_exit: index < Demo::Seeder::EARLY_EXITS_PER_CHURN_YEAR)
    end
    founding_fy2.zip(founding_fy1).each { |previous, current| mark_renewed!(previous, current) }
    founding_fy0 = @founding_members.zip(founding_fy1).map { |member, previous|
      create_membership!(member, fiscal_year: fy0, previous: previous)
    }
    joiners_current = @year_minus_one_joiners.zip(joiners_fy1).map { |member, previous|
      create_membership!(member, fiscal_year: fy0, previous: previous)
    }
    @current_year_joiners.each { |member|
      create_membership!(member, fiscal_year: fy0, late_start: rand < 0.4)
    }
    founding_fy1.zip(founding_fy0).each { |previous, current| mark_renewed!(previous, current) }
    joiners_fy1.zip(joiners_current).each { |previous, current| mark_renewed!(previous, current) }
  end

  def create_membership!(member, fiscal_year: Current.fiscal_year, previous: nil, early_exit: false, late_start: false)
    basket_size, depot, delivery_cycle, extra, division = membership_config_for(fiscal_year, previous)
    deliveries = delivery_cycle.deliveries(fiscal_year.year)
    raise "No deliveries for #{fiscal_year.year} (#{delivery_cycle.name})" if deliveries.empty?

    started_on = membership_started_on(fiscal_year, deliveries, late_start)
    ended_on = membership_ended_on(fiscal_year, deliveries, early_exit)
    membership = Membership.create!(
      member: member,
      basket_size: basket_size,
      basket_size_price: basket_size_price_for(basket_size, fiscal_year),
      basket_price_extra: extra,
      depot: depot,
      depot_price: depot.price,
      delivery_cycle: delivery_cycle,
      delivery_cycle_price: delivery_cycle.price,
      started_on: started_on,
      ended_on: ended_on,
      billing_year_division: division)
    add_membership_complement!(membership, fiscal_year, previous)
    membership
  end

  def membership_started_on(fiscal_year, deliveries, late_start)
    if late_start && deliveries.size > 4
      deliveries[rand(1...(deliveries.size / 3))].date
    else
      fiscal_year.beginning_of_year
    end
  end

  def membership_ended_on(fiscal_year, deliveries, early_exit)
    if early_exit && deliveries.size > 6
      deliveries[-(deliveries.size / 3)].date
    else
      fiscal_year.end_of_year
    end
  end

  def membership_config_for(fiscal_year, previous)
    offset = fy_offset(fiscal_year)
    previous ? renewed_membership_config(offset, previous) : new_membership_config(offset)
  end

  def renewed_membership_config(offset, previous)
    basket_size = rand < 0.3 ? upgrade_basket_size(previous.basket_size) : previous.basket_size
    depot = rand < 0.8 ? previous.depot : depot_for_offset(offset)
    delivery_cycle =
      if depot.delivery_cycles.include?(previous.delivery_cycle) && rand < 0.8
        previous.delivery_cycle
      else
        depot.delivery_cycles.sample
      end
    extra = extra_for_offset(offset, previous: previous)
    division = rand < 0.2 ? division_for_offset(offset) : previous.billing_year_division
    [ basket_size, depot, delivery_cycle, extra, division ]
  end

  def new_membership_config(offset)
    depot = depot_for_offset(offset)
    [
      size_for_offset(offset),
      depot,
      depot.delivery_cycles.sample,
      extra_for_offset(offset),
      division_for_offset(offset)
    ]
  end

  def size_for_offset(offset)
    weights =
      case offset
      when 2 then { @small => 5, @medium => 3, @large => 1 }
      when 1 then { @small => 3, @medium => 4, @large => 2 }
      else { @small => 2, @medium => 3, @large => 3 }
      end
    pick_weighted(weights)
  end

  def depot_for_offset(offset)
    weights =
      case offset
      when 2 then { @farm_depot => 5, @market_depot => 3, @home_depot => 1 }
      when 1 then { @farm_depot => 3, @market_depot => 3, @home_depot => 2 }
      else { @farm_depot => 2, @market_depot => 3, @home_depot => 3 }
      end
    pick_weighted(weights)
  end

  def extra_for_offset(offset, previous: nil)
    extras = Current.org[:basket_price_extras].map(&:to_f)
    return previous.basket_price_extra.to_f if previous && rand < 0.7

    weights =
      case offset
      when 2 then extras.each_with_index.to_h { |extra, index| [ extra, index.zero? ? 5 : 1 ] }
      when 1 then extras.each_with_index.to_h { |extra, index| [ extra, [ 4 - index, 1 ].max ] }
      else extras.each_with_index.to_h { |extra, index| [ extra, index + 1 ] }
      end
    pick_weighted(weights)
  end

  def division_for_offset(offset)
    weights =
      case offset
      when 2 then { 1 => 5, 4 => 2, 12 => 1 }
      when 1 then { 1 => 3, 4 => 3, 12 => 2 }
      else { 1 => 2, 4 => 3, 12 => 3 }
      end
    pick_weighted(weights)
  end

  def upgrade_basket_size(size)
    return @medium if size.id == @small.id
    return @large if size.id == @medium.id

    size
  end

  def basket_size_price_for(basket_size, fiscal_year)
    (basket_size.price * (1 - (0.05 * fy_offset(fiscal_year)))).round(2)
  end

  def add_membership_complement!(membership, fiscal_year, previous)
    previous_complement = previous&.memberships_basket_complements&.first
    keep = previous_complement && rand < 0.7
    chance = { 2 => 0.2, 1 => 0.3 }.fetch(fy_offset(fiscal_year), 0.45)
    return unless keep || rand < chance

    MembershipsBasketComplement.create!(
      membership: membership,
      basket_complement: keep ? previous_complement.basket_complement : @all_complements.sample,
      quantity: 1)
  end

  def mark_renewed!(previous, current)
    previous.update_columns(
      renew: true,
      renewed_at: current.created_at,
      renewal_opened_at: nil)
  end
end
