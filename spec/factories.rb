FactoryBot.define do
  factory :absence do
    member
    started_on { Absence.min_started_on }
    ended_on { Absence.min_started_on + 1.week }
  end

  factory :acp do
    name { 'Rage de Vert' }
    url { 'https://www.ragedevert.ch' }
    logo_url { 'https://d2ibcm5tv7rtdh.cloudfront.net/ragedevert/logo.jpg' }
    email { 'info@ragedevert.ch' }
    phone { '077 447 26 16' }
    sequence(:tenant_name) { |n| "acp#{n}" }
    email_default_host { 'https://membres.ragedevert.ch' }
    email_default_from { 'info@ragedevert.ch' }
    email_signature { "Au plaisir,\nRage de Vert" }
    email_footer { "En cas de questions ou remarques, répondez simplement à cet email.\nAssociation Rage de Vert, Closel-Bourbon 3, 2075 Thielle" }
    trial_basket_count { 4 }
    billing_year_divisions { [1, 4] }
    annual_fee { 30 }
    activity_price { 60 }
    ccp { '01-13734-6' }
    isr_identity { '00 11041 90802 41000' }
    isr_payment_for { "Banque Raiffeisen du Vignoble\n2023 Gorgier" }
    isr_in_favor_of { "Association Rage de Vert\nClosel-Bourbon 3\n2075 Thielle" }
    invoice_info { 'Payable dans les 30 jours, avec nos remerciements.' }
    invoice_footer { '<b>Association Rage de Vert</b>, Closel-Bourbon 3, 2075 Thielle /// info@ragedevert.ch, 076 481 13 84' }
    terms_of_service_url { 'https://www.ragedevert.ch/s/RageDeVert-Reglement-2015.pdf' }
    features { %w[absence activity basket_content] }
    feature_flags { %w[basket_price_extra shop] }
  end

  factory :activity do
    date { Date.current.beginning_of_week + 8.days }
    start_time { '8:30' }
    end_time { '12:00' }
    place { 'Thielle' }
    title { 'Aide aux champs' }
  end

  factory :activity_participation do
    member
    activity
    participants_count { 1 }
    state { 'pending' }

    trait :carpooling do
      carpooling { '1' }
      carpooling_phone { Faker::Base.numerify('+41 ## ### ## ##') }
      carpooling_city { Faker::Address.city }
    end

    trait :validated do
      activity { create(:activity, date: 1.day.ago) }
      state { 'validated' }
      validated_at { Time.current }
      validator { create(:admin) }
    end

    trait :rejected do
      activity { create(:activity, date: 1.day.ago) }
      state { 'rejected' }
      rejected_at { Time.current }
      validator { create(:admin) }
    end
  end

  factory :admin do
    name { 'Bob' }
    email { Faker::Internet.email }
    rights { 'superadmin' }
  end

  factory :basket do
    membership
    basket_size
    depot
    delivery
  end

  factory :basket_complement do
    sequence(:name) { |n| "Basket Complement #{n}" }
    public_name { "#{name} PUBLIC" }
    price { 4.2 }
    delivery_ids {
      DeliveriesHelper.create_deliveries(deliveries_count, fiscal_year)
      Delivery.pluck(:id)
    }

    transient do
      deliveries_count { 0 }
      fiscal_year { Current.fiscal_year }
    end

    trait :annual_price_type do
      price_type { 'annual' }
      price { 200 }
    end
  end

  factory :basket_content do
    vegetable
    delivery { Delivery.first || create(:delivery) }
    quantity { 10 }
    unit { 'kg' }
    depots { [Depot.first || create(:depot)] }
  end

  factory :basket_size do
    sequence(:name) { |n| "Basket Size #{n}" }
    public_name { "#{name} PUBLIC" }
    price { 30 }
    activity_participations_demanded_annualy { 2 }

    trait :small do
      name { 'Eveil' }
      price { 925 / 40.0 }
    end

    trait :big do
      name { 'Abondance' }
      price { 1330 / 40.0 }
    end
  end

  factory :delivery do
    sequence(:date) { |n| Date.today + n.days }

    after(:create) { |d| d.reload }
  end

  factory :deliveries_cycle do
    name { Faker::Name.name }
    public_name { "#{name} PUBLIC" }
  end

  factory :depot do
    name { Faker::Name.name }
    public_name { "#{name} PUBLIC" }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    zip { Faker::Address.zip }
    price { 0 }
    delivery_ids {
      DeliveriesHelper.create_deliveries(deliveries_count, fiscal_year)
      Delivery.pluck(:id)
    }
    deliveries_cycle_ids { create(:deliveries_cycle).id}

    transient do
      deliveries_count { 40 }
      fiscal_year { Current.fiscal_year }
    end
  end

  factory :invoice do
    member
    date { Time.current }
    sent_at { Time.current }

    trait :membership do
      object { create(:membership, member: member) }
      memberships_amount_description { 'Montant' }
    end

    trait :annual_fee do
      object_type { 'AnnualFee' }
      annual_fee { member.annual_fee }
    end

    trait :activity_participation do
      paid_missing_activity_participations { 1 }
      paid_missing_activity_participations_amount { Current.acp.activity_price }
    end

    trait :manual do
      object_type { '' }
    end

    trait :unprocessed do
      sent_at { nil }
    end

    trait :not_sent do
      state { 'not_sent' }
      sent_at { nil }
    end

    trait :open do
      state { 'open' }
      sent_at { Time.current }
    end

    trait :canceled do
      state { 'canceled' }
      canceled_at { Time.current }
    end
  end

  factory :member do
    name { [Faker::Name.last_name, Faker::Name.first_name].join(' ') }
    emails { [Faker::Internet.email, Faker::Internet.email].join(', ') }
    phones { Faker::Base.numerify('+41 ## ### ## ##') }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    zip { Faker::Address.zip }
    billing_year_division { 4 }
    annual_fee { Current.acp.annual_fee }

    validated_at { Time.current }
    validator { Admin.first || create(:admin) }

    created_at { Time.utc(2014) } # no trial by default

    trait :pending do
      state { 'pending' }
      validated_at { nil }
      validator { nil }
      waiting_basket_size { create(:basket_size) }
      waiting_depot { create(:depot) }
    end

    trait :waiting do
      state { 'waiting' }
      waiting_started_at { Time.current }
      waiting_basket_size { create(:basket_size) }
      waiting_depot { create(:depot) }
    end

    trait :trial do
      state { 'active' }
      created_at { Time.current.beginning_of_year }
      after :create do |member|
        DeliveriesHelper.create_deliveries(10)
        create(:membership,
          member: member,
          started_on: [Time.current.beginning_of_year, Delivery.last.date - 3.weeks].max)
      end
    end

    trait :active do
      state { 'active' }
      activated_at { Time.current }
      after :create do |member|
        create(:membership, :last_year, member: member)
        create(:membership, member: member)
      end
    end

    trait :support_annual_fee do
      state { 'support' }
      billing_year_division { 1 }
      annual_fee { Current.acp.annual_fee }
    end

    trait :support_acp_share do
      state { 'support' }
      billing_year_division { 1 }

      transient do
        acp_shares_number { 1 }
      end

      after :create do |member, evaluator|
        create(:invoice, member: member,
          acp_shares_number: evaluator.acp_shares_number)
      end
    end

    trait :inactive do
      state { 'inactive' }
      annual_fee { nil }
    end
  end

  factory :membership do
    member
    basket_size { BasketSize.first || create(:basket_size) }
    depot { create(:depot, fiscal_year: fiscal_year) }
    started_on { fiscal_year.range.min }
    ended_on { fiscal_year.range.max }

    transient do
      fiscal_year { Current.fiscal_year }
    end

    trait :last_year do
      fiscal_year { Current.acp.fiscal_year_for(1.year.ago) }
    end

    trait :next_year do
      fiscal_year { Current.acp.fiscal_year_for(1.year.from_now) }
    end
  end

  factory :payment do
    member
    date { Time.current }
    amount { 1000 }
  end

  factory :session do
    trait :member do
      member
    end

    trait :admin do
      admin
    end

    remote_addr { '127.0.0.1' }
    user_agent { 'a browser user agent' }
  end

  factory :vegetable do
    name { Faker::Food.vegetables }
  end

  factory :group_buying_delivery, class: GroupBuying::Delivery do
    date { 1.month.from_now }
    orderable_until { 2.weeks.from_now }
  end

  factory :group_buying_producer, class: GroupBuying::Producer do
    name { 'la ferme à mathurin' }
    website_url { 'https://lafermeamathurin.com' }
  end

  factory :group_buying_product, class: GroupBuying::Product do
    association :producer, factory: :group_buying_producer
    name { 'Farine de Seigle 5 kg (3.15/kg)' }
    price { 15.75 }
  end

  factory :group_buying_order, class: GroupBuying::Order do
    member
    association :delivery, factory: :group_buying_delivery
    terms_of_service { '1' }
    items_attributes { {
      '0' => {
        product_id: create(:group_buying_product).id,
        quantity: 1
      }
    } }
  end

  factory :shop_producer, class: Shop::Producer do
    name { 'la ferme à mathurin' }
    website_url { 'https://lafermeamathurin.com' }
  end

  factory :shop_product, class: Shop::Product do
    association :producer, factory: :shop_producer
    name { 'Farine de Seigle' }
    variants_attributes { {
      '0' => {
        name: '5 kg',
        price: 16.75
      },
      '1' => {
        name: '10 kg',
        price: 30.5
      }
    } }
  end

  factory :shop_order, class: Shop::Order do
    member
    delivery
    items_attributes {
      product = create(:shop_product)
      {
        '0' => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        }
      }
    }

    trait :cart do
      state { Shop::Order::CART_STATE }
    end
    trait :pending do
      state { Shop::Order::PENDING_STATE }
    end
  end
end
