FactoryBot.define do
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
end
