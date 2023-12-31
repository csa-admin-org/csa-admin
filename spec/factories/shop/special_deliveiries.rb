FactoryBot.define do
  factory :shop_special_delivery, class: Shop::SpecialDelivery do
    open { true }
    date { Date.today + 1.day }
    open_delay_in_days { 0 }
    open_last_day_end_time { Tod::TimeOfDay.parse("12:00:00") }
    products { [ create(:shop_product) ] }
  end
end
