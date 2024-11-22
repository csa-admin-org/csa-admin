# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    member { create(:member, state: "active", activated_at: Time.current) }
    basket_size { BasketSize.first || create(:basket_size) }
    depot { create(:depot) }
    delivery_cycle { depot.delivery_cycles.first }

    started_on { fiscal_year.range.min }
    ended_on { fiscal_year.range.max }
    billing_year_division { 1 }

    transient do
      fiscal_year { Current.fiscal_year }
      deliveries_count { 1 }
    end

    trait :renewed do
      after :create do |membership, _|
        membership.update!(
          renewed_at: Time.current,
          renew: true)
      end
    end

    trait :renewal_canceled do
      renewal_opened_at { nil }
      renewed_at { nil }
      renew { false }
    end

    trait :last_year do
      fiscal_year { Current.org.fiscal_year_for(1.year.ago) }
    end

    trait :next_year do
      fiscal_year { Current.org.fiscal_year_for(1.year.from_now) }
    end

    before :create do |_, evaluator|
      DeliveriesHelper.create_deliveries(
        evaluator.deliveries_count,
        evaluator.fiscal_year)
    end
    after :create do |membership, _|
      membership.reload
    end
  end
end
