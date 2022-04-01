FactoryBot.define do
  factory :comment, class: ActiveAdmin::Comment do
    association :author, factory: :admin
    association :resource, factory: :member
    body { Faker::Lorem.paragraph }
    namespace { 'root' }
  end
end
