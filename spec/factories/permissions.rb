FactoryBot.define do
  factory :permission do
    sequence(:name) { |n| "Permissions #{n}" }
  end
end
