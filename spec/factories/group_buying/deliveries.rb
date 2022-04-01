FactoryBot.define do
  factory :group_buying_delivery, class: GroupBuying::Delivery do
    date { 1.month.from_now }
    orderable_until { 2.weeks.from_now }
  end
end
