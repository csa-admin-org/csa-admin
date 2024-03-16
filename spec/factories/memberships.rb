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

    trait :last_year do
      fiscal_year { Current.acp.fiscal_year_for(1.year.ago) }
    end

    trait :next_year do
      fiscal_year { Current.acp.fiscal_year_for(1.year.from_now) }
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
